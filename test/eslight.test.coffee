sinon = require 'sinon'
chai = require 'chai'
sinonChai = require 'sinon-chai'
chaiAsPromised = require 'chai-as-promised'
nock = require 'nock'
Q = require 'q'
chai.use sinonChai
chai.use chaiAsPromised
should = chai.should()
expect = chai.expect

ESLight = require '../src/eslight'

wait = (time) ->
    def = Q.defer()
    setTimeout((-> def.resolve()), time)
    return def.promise

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



describe 'The exec method', ->

    run = (exec, compare) ->
        es = new ESLight 'http://130.240.19.2:9200'
        es._tryReq = sinon.spy()
        es.exec exec...
        es._tryReq.should.have.been.calledWith compare...

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
        run ['do', 'something'], ['GET', '/do/something', undefined, undefined, true]

    it 'accepts three string params', ->
        run ['do', 'something', 'more'], ['GET', '/do/something/more', undefined, undefined, true]

    it 'accepts one string and an object', ->
        body = {}
        run ['do', body], ['GET', '/do', undefined, body, true]

    it 'accepts two strings and an object', ->
        body = {}
        run ['do', 'something', body], ['GET', '/do/something', undefined, body, true]

    it 'accepts one string and two objects', ->
        query = {}
        body = {}
        run ['do', query, body], ['GET', '/do', query, body, true]

    it 'accepts two strings and two objects', ->
        query = {}
        body = {}
        run ['do', 'something', query, body], ['GET', '/do/something', query, body, true]

    it 'checks whether first argument is GET/POST/PUT/DELETE', ->
        run ['GET', 'do'], ['GET', '/do']
        run ['POST', 'do'], ['POST', '/do']
        run ['PUT', 'do'], ['PUT', '/do']
        run ['DELETE', 'do'], ['DELETE', '/do']



describe 'The _tryReq method', ->

    run = (es, compare) ->
        es._doReq = sinon.spy()
        es._tryReq 'GET', '/do'
        es._doReq.should.have.been.calledWith compare

    it 'round robbins the endpoints', ->
        es = new ESLight 'http://130.240.19.2:9200'
        es._endpoints = [{end:1, _count:0}, {end:2, _count:0}, {end:3, _count:0}]
        run es, es._endpoints[0]
        run es, es._endpoints[1]
        run es, es._endpoints[2]
        run es, es._endpoints[0]
        run es, es._endpoints[1]
        run es, es._endpoints[2]
        run es, es._endpoints[0]

    it 'skips disabled endpoints', ->
        es = new ESLight 'http://130.240.19.2:9200'
        es._endpoints = [{end:1, _count:0, _disabled: true},
            {end:2, _count:0}, {end:3, _count:0}]
        run es, es._endpoints[1]
        run es, es._endpoints[2]
        run es, es._endpoints[1]

    it 'reenables endpoints after _wait', (done) ->
        es = new ESLight 'http://130.240.19.2:9200'
        now = (new Date()).getTime()
        es._endpoints = [{end:1, _count:0},
            {end:2, _count:0, _disabled: true, _wait: now + 10}, {end:3, _count:0}]
        run es, es._endpoints[0]
        run es, es._endpoints[2]
        wait(30)
            .then ->
                run es, es._endpoints[1]
                done()
            .fail (err) ->
                done(err)

    it 'mustnt overload a reenabled endpoint', (done) ->
        es = new ESLight 'http://130.240.19.2:9200'
        now = (new Date()).getTime()
        es._endpoints = [{end:1, _count:0}, {end:2, _count:0, _disabled: true, _wait: now + 20}]
        for x in [0..10]
            run es, es._endpoints[0]
        wait(40)
            .then ->
                run es, es._endpoints[1]
                run es, es._endpoints[0]
                run es, es._endpoints[1]
                done()
            .fail (err) ->
                done(err)

    it 'retries on shard not available (without disabling)', (done) ->
        es = new ESLight 'http://130.240.19.2:9200'
        es._endpoints = [{end:1, _count:0}]
        es._doReq = -> Q({statusCode:500,body:error:'NoShardAvailableActionException'})
        (es._tryReq 'GET', '/do').fail (res) ->
            res.should.equal 'NoShardAvailableActionException'
            es._endpoints.should.deep.equal [{end:1,_count:1}]
            done()
        .done()


describe 'The _doReq method', ->

    endpoint = { host: 'my.host.com', port: 9200 }

    run = (args, override, body) ->
        compare = extend({}, endpoint, override)
        es = new ESLight 'http://130.240.19.2:9200'
        es._dispatch = sinon.spy()
        args.unshift endpoint
        es._doReq args...
        es._dispatch.should.have.been.calledWith compare, body

    it 'runs a simple GET', ->
        run ['GET', '/do'], { method: 'GET', path: '/do' }

    it 'runs a simple POST', ->
        run ['POST', '/do'], { method: 'POST', path: '/do' }

    it 'appends the query to path', ->
        run ['GET', '/do', {version:1,foo:true}], {method: 'GET', path: '/do?version=1&foo=true'}

    it 'sets application/json header for body request', ->
        run ['GET', '/do', null, {body:true}], {
            method: 'GET',
            path: '/do',
            headers: { "Content-Type": "application/json" }
        }, {body: true}


describe 'The http request', ->

    serv = (nock 'http://130.240.19.2:9200').persist()
        .get('/do').reply(200)
        .get('/fail').reply(500)
        .get('/bad').reply(400)
        .get('/error').reply(400, {error:'errormsg'})
        .get('/body').reply(200, {the:true,thing:1})

    serv2 = (nock 'http://130.240.19.3:9200').persist()
        .get('/fail').reply(200)

    it 'responds 200 to a simple GET', (done) ->
        es = new ESLight 'http://130.240.19.2:9200'
        cb = sinon.spy()
        (es.exec '/do').should.be.fulfilled.and.notify done

    it 'rejects results with a error property', (done) ->
        es = new ESLight 'http://130.240.19.2:9200'
        cb = sinon.spy()
        ((es.exec '/error').should.be.rejectedWith('errormsg').and.notify(done))
            .then ->
                es._endpoints[0]._count.should.equals 1
                expect(es._endpoints[0]._disabled).to.be.undefined
            .done()

    it 'rejects results with a error status code', (done) ->
        es = new ESLight 'http://130.240.19.2:9200'
        cb = sinon.spy()
        (es.exec '/error').fail (err) ->
            err.statusCode.should.equals 400
            done()

    it 'disable and try another endpoint on 500', (done) ->
        es = new ESLight 'http://130.240.19.2:9200', 'http://130.240.19.3:9200'
        cb = sinon.spy()
        ((es.exec 'GET', '/fail').should.become({}))
            .then ->
                es._endpoints[0]._count.should.equals 1
                es._endpoints[0]._disabled.should.be.true
                es._endpoints[0]._wait.should.exist
                done()
            .fail (err) ->
                done(err)

    it 'responds with the 500 if there is only one endpoint', (done) ->
        es = new ESLight 'http://130.240.19.2:9200'
        cb = sinon.spy()
        ((es.exec 'GET', '/fail').should.become(undefined))
            .then ->
                done(new Error('No good'))
            .fail (err) ->
                es._endpoints[0]._count.should.equal 1
                expect(err.status).to.be.undefined
                done()
            .done()

    it 'responds 400 to bad GET', (done) ->
        es = new ESLight 'http://130.240.19.2:9200'
        cb = sinon.spy()
        (es.exec '/bad')
            .then (res) ->
                res.should.be.deep.equal {}
                done()
            .done()

    it 'returns a body if there is one', (done) ->
        es = new ESLight 'http://130.240.19.2:9200'
        cb = sinon.spy()
        (es.exec '/body').should.become({the:true,thing:1}).and.notify done

    it 'passes the body all the way', ->
        es = new ESLight 'http://130.240.19.2:9200'
        es._endpoints = [{end:1,_count:0}]
        es._dispatch = sinon.spy()
        es.exec '/do', {body:true}
        es._dispatch.should.have.been.calledWith({
            _count: 1,
            end: 1,
            headers:  {"Content-Type": "application/json" },
            method: "GET",
            path: "/do"
            }, { body: true })
