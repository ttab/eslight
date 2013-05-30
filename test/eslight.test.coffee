chai = require 'chai'
chai.should()

ESLight = require '../src/eslight'

describe 'Instantiating client with...', ->
    it 'empty constructor', ->
        eslight = new ESLight()
    it 'just a string', ->
        eslight = new ESLight 'http://130.240.19.2:9200'
