ConnectionFactory = require("../../lib/backends/factory.coffee")
{PerseidsConnection} = require("../../lib/backends/perseids/connection.coffee")
{AwaitQuery} = require("../../lib/backends/perseids/cursors.coffee")
assert = require('chai').assert

log = (args...) ->
  console.log('----------------------vvvvv')
  console.log(args)
  console.log('----------------------^^^^^')


describe 'PerseidsConnection', ->
  it "should support server directives for throttling"

  it "should be configuratable with https"

  it "should be configuratable with http"

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
      #log(err)
    done()

  it "should getServers() from production and cache them", (done) ->
    @timeout(4000)
    connection = new PerseidsConnection('production')
    connection.on '*', log
    list = null
    connection.getServers().then (list1) ->
      list = list1
      assert.equal(list.length > 0, true, list.join(", "))
      assert.equal(list[0].indexOf('https://ct') == 0, true, list[0])
      connection.baseUrl = 'none' # ensure we can't refetch
      return connection.getServers()
    .then (list2) ->
      assert.equal(list, list2)
      done()
    .catch done


  it "should getServers(params) from production and not cache them", (done) ->
    @timeout(4000)
    connection = new PerseidsConnection('production')
    connection.on '*', log
    list = null
    connection.getServers(a: true).then (list1) ->
      list = list1
      assert.equal(list.length > 0, true, list.join(", "))
      assert.equal(list[0].indexOf('https://ct') == 0, true, list[0])
      return connection.getServers(b: true)
    .then (list2) ->
      assert.notStrictEqual(list2, list)
      done()
    .catch done


  it "should fallback on bad servers request", (done) ->
    connection = new PerseidsConnection(host: 'http://example.com')
    connection.on '*', log
    connection.getServers().then (list) ->
      assert.deepEqual(list, ['http://example.com'])
      done()
    .catch done

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
    .catch done

  it 'should rethrow on a bad fetch', (done) ->
    @timeout(4000)
    connection = new PerseidsConnection('production')
    connection.on '*', log
    connection.fetch('/meow').then (m) ->
      assert.fail("should have 404'd")
    .catch (err) ->
      assert.equal(err.status, 404)
      done()
    .catch done



