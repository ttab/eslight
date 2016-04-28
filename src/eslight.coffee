http = require 'http'
url = require 'url'
Q = require 'q'
querys = require 'querystring'
stream = require 'stream'

slice = (a) ->
    Array.prototype.slice.call(a, 0)

extend = (target, objects...) ->
    for object in objects
        for own key, value of object
            target[key] = value
    return target

ERROR_WAIT = 2000
MAX_RETRIES = 10
BACKOFF_MILLIS = 200

METHODS = ['GET', 'POST', 'PUT', 'DELETE', 'HEAD']

NO_SHARD = 'NoShardAvailableActionException'

ERRORCODES = ['ECONNREFUSED', 'ENETUNREACH', 'ECONNRESET', 'ETIMEDOUT']

class ESLight

    constructor: (endpoints...) ->
        throw 'expected endpoints' if !endpoints.length
        e = endpoints
        e = [].concat e... if e.reduce ((p,c) -> Array.isArray(c) or p), false
        @_endpoints = e.map (c) -> if typeof c == 'string' then url.parse c else c
        # setup endpoint counters
        c._count = 0 for c in @_endpoints

    _parseExecArgs: (oper, query, body) ->

        throw 'bad args' if !oper

        args = slice arguments
        len = args.length
        if len >= 2 and typeof args[len-1] == 'object'
            body = args[len-1]
            len--
        else
            body = undefined
        if len >= 2 and typeof args[len-1] == 'object'
            query = args[len-1]
            len--
        else
            query = undefined
        oper = args.slice 0, len
        method = 'GET'
        method = oper.shift() if oper[0] in METHODS

        throw 'bad args' if !oper.length

        path = oper.join '/'
        path = '/' + path if (path.indexOf '/') != 0

        return [method, path, query, body]

    exec: (oper, query, body) ->

        [method, path, query, body] = @_parseExecArgs.apply this, arguments

        def = Q.defer()
        attempts = MAX_RETRIES
        lastErr = null
        firstTry = true

        doAttempt = =>
            if --attempts <= 0
                def.reject lastErr
                return
            backoff = calcBackoff (MAX_RETRIES - attempts)
            prom = (@_tryReq method, path, query, body, firstTry)
            firstTry = false

            if Q.isPromise prom
                (prom)
                    .then (res) ->
                        def.resolve res
                    .fail (err) ->
                        if 500 <= err.statusCode <= 599
                            lastErr = err
                            scheduleAttempt backoff
                        else if err.code in ERRORCODES
                            lastErr = err
                            scheduleAttempt backoff
                        else if err == 'no retry'
                            def.reject lastErr
                        else if err instanceof Error
                            def.reject err
                        else if err?.body?.error
                            def.reject err
                        else if err?.statusCode
                            def.reject err

                        else
                            lastErr = err
                            scheduleAttempt backoff
                    .done()

        scheduleAttempt = (backoff) => setTimeout doAttempt, backoff

        # start trying
        doAttempt()

        return def.promise

    _tryReq: (method, path, query, body, firstTry) ->

        isUsable = (e) ->
            return !e._disabled or (new Date()).getTime() > e._wait

        maxcount = 0

        endpoint = @_endpoints.reduce ((prev, cur) ->
            maxcount = Math.max cur._count, maxcount
            return cur if not prev or not (isUsable prev) or \
                (isUsable cur) and cur._count < prev._count
            prev), null

        def = Q.defer()

        # reenable endpoint
        if isUsable endpoint
            if endpoint._disabled
                endpoint._count = maxcount - 1
                delete endpoint._disabled
                delete endpoint._wait
        else if !firstTry
            # signal that we don't want more retries
            def.reject('no retry')
            return def.promise

        # increase call count
        endpoint._count++

        disable = ->
            endpoint._disabled = true
            endpoint._wait = (new Date()).getTime() + ERROR_WAIT

        (@_doReq endpoint, method, path, query, body).then (res) ->
            def.resolve res.body
        .fail (res) ->
            if res.statusCode
                available = !(res?.message?.indexOf?(NO_SHARD) == 0)
                disable() if available and 500 <= res.statusCode <= 599
            def.reject res
        .done()

        return def.promise

    _doReq: (endpoint, method, path, query, body) ->

        path += '?' + querys.stringify(query) if query

        opts = extend({}, endpoint, {method: method, path: path})

        opts.headers = {'Content-Type': 'application/json'} if body

        @_dispatch opts, body

    _dispatch: (opts, body) ->
        def = Q.defer()
        req = http.request opts, (res) ->
            body = null
            res.setEncoding 'utf-8'
            res.on 'data', (chunk) ->
                body = '' if !body
                body += chunk
            res.on 'end', ->
                if body
                    try
                        res.body = JSON.parse body
                    catch err
                        res.body = body
                if 200 <= res.statusCode <= 299
                    def.resolve res
                else
                    def.reject res

        # send body if there is one
        if body
            if !(body instanceof Buffer) and typeof body != 'string'
                body = (JSON.stringify body)
            # at this point the body ought to be a 'string', convert to buffer
            # to ensure we can send really large object
            body = new Buffer body
            req.setHeader 'Content-Length', body.length
            req.write body

        req.on 'error', (err) ->
            def.reject err
        req.end()

        return def.promise


# https://en.wikipedia.org/wiki/Exponential_backoff#An_example_of_an_exponential_back-off_algorithm
calcBackoff = (attempt) ->
    # In general, after the cth failed attempt, resend the frame after
    # k · 51.2μs, where k is a random number between 0 and 2^c − 1.
    # ... we can skip -1 since we do Math.floor instead
    k = Math.floor(Math.random() * Math.pow(2,attempt))
    k * BACKOFF_MILLIS


module.exports = ESLight
