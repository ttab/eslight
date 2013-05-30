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
        @_nextend = 0

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
        @_doReq method, path, query, body

    _doReq: (method, path, query, body) ->

        path += '?' + querys.stringify(query) if query
        
        opts = extend({}, @_endpoints[@_nextend], {method: method, path: path})

        opts.headers = {'Content-Type': 'application/json'} if body
        
        # round robbin
        if @_endpoints.length
            @_nextend++
            @_nextend = 0 if @_nextend == @_endpoints.length

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
