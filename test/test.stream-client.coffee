assert = require('chai').assert

log = console.log.bind(console)

describe.skip 'livefyre-stream-client', ->
  it 'should require in node without barfing.', ->
    client = require 'livefyre-stream-client'
    assert(client?)

describe.skip 'StreamClient should work against production', ->
  urn = "urn:livefyre:cnn.fyre.co:site=353270:topic=54a2fe0def40ce028cedb0b4:topicStream"

  it "should work on #{urn}", ->
    {StreamClient} = require '../lib/stream.coffee'
    client = new StreamClient('production')
    client.on '*', log
    subscription = client.subscribe(urn)
    subscription.close()
