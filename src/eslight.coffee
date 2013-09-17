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
MAX_RETRIES = 5

class ESLight

    constructor: (endpoints...) ->
        throw 'expected endpoints' if !endpoints.length
        if endpoints.length
            if typeof endpoints[0] == 'string'
                @_endpoints = (url.parse e for e in endpoints)
            else
                @_endpoints = endpoints
        else
            @_endpoints = null
        # setup endpoint counters
        ((e) -> e._count = 0) e for e in @_endpoints

    exec: (oper, query, body) ->

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
        method = oper.shift() if oper[0] in ['GET', 'POST', 'PUT', 'DELETE']

        throw 'bad args' if !oper.length

        path = oper.join '/'
        path = '/' + path if (path.indexOf '/') != 0

        def = Q.defer()
        attempts = MAX_RETRIES
        lastErr = null
        firstTry = true

        doAttempt = () =>
            if --attempts <= 0
                def.reject lastErr
                return
            prom = (@_tryReq method, path, query, body, firstTry)
            firstTry = false
            if Q.isPromise prom
                (prom)
                    .then (res) ->
                        if 500 <= res.status <= 599
                            lastErr = res
                            doAttempt()
                        else
                            def.resolve res
                    .fail (err) ->
                        if err == 'no retry'
                            def.reject lastErr
                        else if err instanceof Error
                            def.reject err
                        else
                            lastErr = err
                            doAttempt()

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

        prom = @_doReq endpoint, method, path, query, body

        disable = ->
            endpoint._disabled = true
            endpoint._wait = (new Date()).getTime() + ERROR_WAIT

        if Q.isPromise prom
            (prom)
                .then (res) ->
                    if 500 <= res.statusCode <= 599
                        disable()
                    if res.body and res.body.error
                        def.reject new Error(res.body.error)
                    else
                        def.resolve res.body ? {}
                .fail (err) ->
                    disable()
                    def.reject(err)

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
                def.resolve res

        # send body if there is one
        if body
            if !(body instanceof Buffer) and typeof body != 'string'
                body = (JSON.stringify body)
            req.setHeader 'Content-Length', body.length
            req.write body

        req.on 'error', (err) -> def.reject err
        req.end()

        return def.promise

module.exports = ESLight
