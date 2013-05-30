http = require 'http'
url = require 'url'
Q = require 'q'

slice = (a) ->
    Array.prototype.slice.call(a, 0)

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
        @_nextClient = 0
        @_clients = []

    exec: (oper, body, callback) ->
        args = slice arguments
        len = args.length 
        if len >= 2 and typeof args[len-1] == 'function'
            callback = args[len-1]
            len--
        else
            callback = undefined
        if len >= 2 and typeof args[len-1] == 'object'
            body = args[len-1]
            len--
        else
            body = undefined
        oper = args.slice 0, len
        path = oper.join '/'
        path = '/' + path if (path.indexOf '/') != 0
        @_reqPath path, body, callback

    _reqPath: (path, body, callback) ->

        client = @_clients[@_nextClient]
        client = @_clients[@_nextClient] = \
            @_createClient @_endpoints[@_nextClient] if not client

        @_nextClient++
        @_nextClient = 0 if @_nextClient == @_endpoints.length

    _createClient: (endpoint) ->
        console.info 'create client'

module.exports = ESLight
