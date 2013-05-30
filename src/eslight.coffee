http = require 'http'

class ESLight

    constructor: (opts, endpoints...) ->

    connect: (httpClient) ->
        @httpClient = [httpClient]

module.exports = ESLight
