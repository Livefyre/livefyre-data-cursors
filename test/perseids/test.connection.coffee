ConnectionFactory = require("../../lib/backends/factory.coffee")
{PerseidsConnection} = require("../../lib/backends/perseids/connection.coffee")
{AwaitQuery} = require("../../lib/backends/perseids/cursors.coffee")
assert = require('chai').assert

log = (args...) ->
  console.log('----------------------vvvvv')
  console.log(args)
  console.log('----------------------^^^^^')


describe 'PerseidsConnection vs production', ->
  it "should have the production url", (done) ->
    connection = ConnectionFactory('production', {}).perseids()
    assert.equal(connection.baseUrl, 'https://stream1.livefyre.com')
    done()

  it "should have a custom url", (done) ->
    connection = new PerseidsConnection({host: "meow"})
    assert.equal(connection.baseUrl, 'meow')
    done()

  it "should fail without url", (done) ->
    try
      connection = new PerseidsConnection({moo: "meow"})
      assert.equal(false, 'Should have failed')
    catch err
      log(err)
    done()

  it "should getServers", (done) ->
    @timeout(4000)
    connection = new PerseidsConnection('production')
    connection.on '*', log
    connection.getServers().then (list) ->
      assert.equal(list.length > 0, true, list.join(", "))
      assert.equal(list[0].indexOf('https://ct') == 0, true, list[0])
      assert.equal(Array.isArray(connection._cachedDsrServers), true)
      connection.getServers().then (list2) ->
        assert.equal(true, list2 == list)
        done()

  it "should fallback on bad servers request", (done) ->
    connection = new PerseidsConnection(host: 'http://example.com')
    connection.on '*', log
    connection.getServers().then (list) ->
      assert.deepEqual(list, ['http://example.com'])
      done()

  it "should handle ping", (done) ->
    @timeout(4000)
    connection = new PerseidsConnection('production')
    connection.on '*', log
    connection.fetch('/v3.1/collection/PING/0/').then (m) ->
      result = m.data
      assert.equal(result.code, 200)
      assert.equal(result.status, "ok")
      assert.equal(result.data.maxEventId, 1)
      done()

  it 'should rethrow on a bad fetch', (done) ->
    @timeout(4000)
    connection = new PerseidsConnection('production')
    connection.on '*', log
    connection.fetch('/meow').then (m) ->
      assert.fail("should have 404'd")
    .catch (err) ->
      assert.equal(err.status, 404)
      done()


