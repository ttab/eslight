sinon = require 'sinon'
chai = require 'chai'
sinonChai = require 'sinon-chai'
nock = require 'nock'
chai.use sinonChai
should = chai.should()

ESLight = require '../src/eslight'

extend = (target, objects...) ->
    for object in objects
        for own key, value of object
            target[key] = value
    return target

describe 'Instantiating client, check constructor', ->

    it 'accepts no arguments', ->
        (-> new ESLight())
            .should.throw('expected endpoints')

    it 'accepts just a string', ->
        es = new ESLight 'http://130.240.19.2:9200'
        es.should.have.property '_endpoints'
        es._endpoints.should.be.an 'array'
        es._endpoints.length.should.equal 1
        es._endpoints[0].hostname.should.equal '130.240.19.2'
        es._endpoints[0].port.should.equal '9200'

    it 'accepts many string', ->
        es = new ESLight 'http://130.240.19.2:9200', 'http://10.10.10.1:9200'
        es.should.have.property '_endpoints'
        es._endpoints.should.be.an 'array'
        es._endpoints.length.should.equal 2
        es._endpoints[0].hostname.should.equal '130.240.19.2'
        es._endpoints[1].hostname.should.equal '10.10.10.1'

    it 'accepts any crap that isnt string', ->
        es = new ESLight {some:true,crap:''}, {my:false,thing:''}
        es.should.have.property '_endpoints'
        es._endpoints.should.be.an 'array'
        es._endpoints.length.should.equal 2
        es._endpoints[0].some.should.equal true

describe 'Check new object', ->

    it 'has some default fields', ->
        es = new ESLight 'http://130.240.19.2:9200'
        es.should.have.property '_nextend'
        es._nextend.should.equal 0

describe 'The exec method', ->

    run = (exec, compare) ->
        es = new ESLight 'http://130.240.19.2:9200'
        es._doReq = sinon.spy()
        es.exec exec...
        es._doReq.should.have.been.calledWith compare...

    it 'rejects empty arguments', ->
        (-> run [], []).should.throw('bad args')

    it 'rejects GET/POST/PUT/DELETE with nothing else', ->
        (-> run ['GET'], []).should.throw('bad args')
        (-> run ['POST'], []).should.throw('bad args')


    it 'accepts one string param', ->
        run ['/do'], ['GET', '/do']

    it 'auto prepends /', ->
        run ['do'], ['GET', '/do']

    it 'accepts two string params', ->
        run ['do', 'something'], ['GET', '/do/something', undefined, undefined]

    it 'accepts three string params', ->
        run ['do', 'something', 'more'], ['GET', '/do/something/more', undefined, undefined]

    it 'accepts one string and an object', ->
        body = {}
        run ['do', body], ['GET', '/do', undefined, body, undefined]

    it 'accepts two strings and an object', ->
        body = {}
        run ['do', 'something', body], ['GET', '/do/something', undefined, body, undefined]

    it 'accepts one string and two objects', ->
        query = {}
        body = {}
        run ['do', query, body], ['GET', '/do', query, body]

    it 'accepts two strings and two objects', ->
        query = {}
        body = {}
        run ['do', 'something', query, body], ['GET', '/do/something', query, body]

    it 'checks whether first argument is GET/POST/PUT/DELETE', ->
        run ['GET', 'do'], ['GET', '/do']
        run ['POST', 'do'], ['POST', '/do']
        run ['PUT', 'do'], ['PUT', '/do']
        run ['DELETE', 'do'], ['DELETE', '/do']

describe 'The _doReq method', ->

    inv = {
      auth: null,
      hash: null,
      host: "130.240.19.2:9200",
      hostname: "130.240.19.2",
      href: "http://130.240.19.2:9200/",
      pathname: "/",
      port: "9200",
      protocol: "http:",
      query: null,
      search: null,
      slashes: true
    }

    run = (args, override) ->
        compare = extend({}, inv, override)
        es = new ESLight 'http://130.240.19.2:9200'
        es._dispatch = sinon.spy()
        es._doReq args...
        es._dispatch.should.have.been.calledWith compare


    it 'runs a simple GET', ->
        run ['GET', '/do'], { method: 'GET', path: '/do' }

    it 'runs a simple POST', ->
        run ['POST', '/do'], { method: 'POST', path: '/do' }

    it 'appends the query to path', ->
        run ['GET', '/do', {version:1,foo:true}], {method: 'GET', path: '/do?version=1&foo=true'}

    it 'round robbins the endpoints', ->
        es = new ESLight 'http://130.240.19.2:9200' 
        es._dispatch = sinon.spy()
        es._endpoints = [{end:1}, {end:2}, {end:3}]
        es._nextend.should.equal 0
        es._doReq 'GET', '/do'
        es._nextend.should.equal 1
        es._doReq 'GET', '/do'
        es._nextend.should.equal 2
        es._doReq 'GET', '/do'
        es._nextend.should.equal 0

describe 'The http request', ->

    serv = (nock 'http://130.240.19.2:9200')
        .intercept('/do', 'GET')
        .reply 200

    it 'responds', ->
        es = new ESLight 'http://130.240.19.2:9200'
        (es.exec 'GET', '/do')
            .then (res) ->
