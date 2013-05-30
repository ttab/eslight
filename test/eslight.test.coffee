sinon = require 'sinon'
chai = require 'chai'
sinonChai = require 'sinon-chai'
chai.use sinonChai
should = chai.should()
expect = chai.expect

ESLight = require '../src/eslight'

describe 'Instantiating client, check constructor', ->
        
    it 'accepts no arguments', ->
        (-> new ESLight())
            .should.throw('expected endpoints')
        
    it 'accepts just a string', ->
        es = new ESLight 'http://130.240.19.2:9200'
        es.should.have.property '_endpoints'
        expect(es._endpoints).to.be.an 'array'
        expect(es._endpoints.length).to.equal 1
        expect(es._endpoints[0].hostname).to.equal '130.240.19.2'
        expect(es._endpoints[0].port).to.equal '9200'
        
    it 'accepts many string', ->
        es = new ESLight 'http://130.240.19.2:9200', 'http://10.10.10.1:9200'
        es.should.have.property '_endpoints'
        expect(es._endpoints).to.be.an 'array'
        expect(es._endpoints.length).to.equal 2
        expect(es._endpoints[0].hostname).to.equal '130.240.19.2'
        expect(es._endpoints[1].hostname).to.equal '10.10.10.1'

    it 'accepts any crap that isnt string', ->
        es = new ESLight {some:true,crap:''}, {my:false,thing:''}
        es.should.have.property '_endpoints'
        expect(es._endpoints).to.be.an 'array'
        expect(es._endpoints.length).to.equal 2
        expect(es._endpoints[0].some).to.equal true

describe 'Check new object', ->

    it 'has some default fields', ->
        es = new ESLight 'http://130.240.19.2:9200'
        es.should.have.property '_nextClient'
        expect(es._nextClient).to.equal 0
        es.should.have.property '_clients'
        expect(es._clients).to.be.an 'array'
        expect(es._clients).to.be.empty
        expect(es._clients.length).to.be.equal 0

describe 'The exec method', ->

    it 'accepts one string param', ->
        es = new ESLight 'http://130.240.19.2:9200'
        es._reqPath = sinon.spy()
        es.exec '/do'
        es._reqPath.should.have.been.calledWith '/do'

    it 'auto prepends /', ->
        es = new ESLight 'http://130.240.19.2:9200'
        es._reqPath = sinon.spy()
        es.exec 'do'
        es._reqPath.should.have.been.calledWith '/do'

    it 'accepts two string params', ->
        es = new ESLight 'http://130.240.19.2:9200'
        es._reqPath = sinon.spy()
        es.exec 'do', 'something'
        es._reqPath.should.have.been.calledWith '/do/something', undefined, undefined

    it 'accepts three string params', ->
        es = new ESLight 'http://130.240.19.2:9200'
        es._reqPath = sinon.spy()
        es.exec 'do', 'something', 'more'
        es._reqPath.should.have.been.calledWith '/do/something/more', undefined, undefined

    it 'accepts one string and a callback', ->
        es = new ESLight 'http://130.240.19.2:9200'
        es._reqPath = sinon.spy()
        callback = ->
        es.exec 'do', callback
        es._reqPath.should.have.been.calledWith '/do', undefined, callback

    it 'accepts two strings and a callback', ->
        es = new ESLight 'http://130.240.19.2:9200'
        es._reqPath = sinon.spy()
        callback = ->
        es.exec 'do', 'something', callback
        es._reqPath.should.have.been.calledWith '/do/something', undefined, callback

    it 'accepts one string and an object', ->
        es = new ESLight 'http://130.240.19.2:9200'
        es._reqPath = sinon.spy()
        body = {}
        es.exec 'do', body
        es._reqPath.should.have.been.calledWith '/do', body, undefined

    it 'accepts two strings and an object', ->
        es = new ESLight 'http://130.240.19.2:9200'
        es._reqPath = sinon.spy()
        body = {}
        es.exec 'do', 'something', body
        es._reqPath.should.have.been.calledWith '/do/something', body, undefined

    it 'accepts one strings, an object and a callback', ->
        es = new ESLight 'http://130.240.19.2:9200'
        es._reqPath = sinon.spy()
        callback = ->
        body = {}
        es.exec 'do', body, callback
        es._reqPath.should.have.been.calledWith '/do', body, callback

    it 'accepts two strings, an object and a callback', ->
        es = new ESLight 'http://130.240.19.2:9200'
        es._reqPath = sinon.spy()
        callback = ->
        body = {}
        es.exec 'do', 'something', body, callback
        es._reqPath.should.have.been.calledWith '/do/something', body, callback

describe 'The _reqPath method', ->

    it 'creates a client when there is none', ->
        es = new ESLight 'http://130.240.19.2:9200'
        es._endpoints = [{end:1}, {end:2}]
        es._createClient = sinon.spy()
        es._reqPath '/do'
        es._createClient.should.have.been.calledWith {end:1}

    it 'round robins the _nextClient field', ->
        es = new ESLight 'http://130.240.19.2:9200'
        es._endpoints = [{end:1}, {end:2}, {end:3}]
        es._createClient = sinon.spy()
        expect(es._nextClient).to.be.equal 0
        es._reqPath '/do'
        expect(es._nextClient).to.be.equal 1
        es._reqPath '/do'
        expect(es._nextClient).to.be.equal 2
        es._reqPath '/do'
        expect(es._nextClient).to.be.equal 0

    it 'creates new _clients for each _endpoints', ->
        es = new ESLight 'http://130.240.19.2:9200'
        es._endpoints = [{end:1}, {end:2}]
        expect(es._clients).to.be.empty
        es._createClient = sinon.stub().returns('client')    
        es._reqPath '/do'
        expect(es._clients.length).to.be.equal 1
        expect(es._clients[0]).to.be.equal 'client'
        es._reqPath '/do'
        expect(es._clients.length).to.be.equal 2
        expect(es._clients[0]).to.be.equal 'client'
        expect(es._clients[1]).to.be.equal 'client'
        es._reqPath '/do'
        expect(es._clients.length).to.be.equal 2
