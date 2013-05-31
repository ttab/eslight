http = require 'http'
url = require 'url'
Q = require 'q'
querys = require 'querystring'

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
        
        doAttempt = () =>
            if --attempts <= 0
                def.reject lastErr
                return
            prom = (@_tryReq method, path, query, body)
            if Q.isPromise prom
                (prom)
                    .then (res) ->
                        if !res._statusCode
                            def.resolve res
                        else if 500 <= res._statusCode <= 599
                            lastErr = res                            
                            doAttempt()
                        else
                            def.reject res
                    .fail (err) ->
                        lastErr = err
                        doAttempt()
            
        doAttempt()
                
        return def.promise

    _tryReq: (method, path, query, body) ->

        isUsable = (e) ->
            return !e._disabled or (new Date()).getTime() > e._wait

        maxcount = 0
                                    
        endpoint = @_endpoints.reduce ((prev, cur) ->
            maxcount = Math.max cur._count, maxcount
            return cur if not prev or not (isUsable prev) or \
                (isUsable cur) and cur._count < prev._count
            prev), null

        # reenable endpoint
        if endpoint._disabled
            endpoint._count = maxcount - 1
            delete endpoint._disabled
            delete endpoint._wait

        # increase call count
        endpoint._count++

        prom = @_doReq endpoint, method, path, query, body

        def = Q.defer()

        disable = ->
            endpoint._disabled = true
            endpoint._wait = (new Date()).getTime() + ERROR_WAIT

        if Q.isPromise prom
            (prom)
                .then (res) ->
                    if 500 <= res.statusCode <= 599
                        disable()
                    body = res.body ? {}
                    body._statusCode = res.statusCode if not (200 <= res.statusCode <= 299)
                    def.resolve body
                .fail (err) ->
                    disable()
                    def.reject(err)

        return def.promise    

    _doReq: (endpoint, method, path, query, body) ->

        path += '?' + querys.stringify(query) if query
        
        opts = extend({}, endpoint, {method: method, path: path})

        opts.headers = {'Content-Type': 'application/json'} if body
        
        @_dispatch opts
   
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
        req.write (JSON.stringify body) if body

        req.on 'error', (err) -> def.reject err
        
        req.end()        
            
        return def.promise

module.exports = ESLight
