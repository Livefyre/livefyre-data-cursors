ConnectionFactory = require("../../lib/backends/factory.coffee")
{PerseidsConnection} = require("../../lib/backends/perseids/connection.coffee")
{AwaitQuery} = require("../../lib/backends/perseids/cursors.coffee")
assert = require('chai').assert

log = (args...) ->
  console.log('----------------------vvvvv')
  console.log(args)
  console.log('----------------------^^^^^')


describe 'PerseidsConnection', ->
  it "#constructor should be configurable with https", ->
    c = new PerseidsConnection({baseUrl: "https://meow"})
    assert.ok(c._secure == true)

  it "#constructor should be configurable with http", ->
    c = new PerseidsConnection({baseUrl: "http://meow"})
    assert.ok(c._secure == false)

  it "#constructor via ConnectionFactory should have the production url by name", (done) ->
    connection = ConnectionFactory('production', {}).perseids()
    assert.equal(connection.baseUrl, 'https://stream1.livefyre.com')
    done()

  it "#constructor should support a custom url", (done) ->
    connection = new PerseidsConnection({baseUrl: "http://meow"})
    assert.equal(connection.baseUrl, 'http://meow')
    done()

  it "#should should fail without url", (done) ->
    try
      connection = new PerseidsConnection({moo: "meow"})
      assert.equal(false, 'Should have failed')
    catch err
      #log(err)
    done()

  it "#getServers() should get from production and cache", (done) ->
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

  it "#getServers(params) should get from production and not cache them", (done) ->
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

  it "#getServers() over http should have http: list", (done) ->
    @timeout(4000)
    connection = new PerseidsConnection(baseUrl: "http://stream1.livefyre.com")
    connection.on '*', log
    connection.getServers().then (list) ->
      assert.equal(list.length > 0, true, list.join(", "))
      assert.equal(list[0].indexOf('http://ct') == 0, true, list[0])
      done()
    .catch done


  it "#getServers should fallback to baseUrl on bad servers request", (done) ->
    connection = new PerseidsConnection(baseUrl: 'http://example.com')
    connection.on '*', log
    connection.getServers().then (list) ->
      assert.deepEqual(list, ['http://example.com'])
      done()
    .catch done

  it "#fetch should handle PING", (done) ->
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

  it '#fetch should rethrow on a bad fetch', (done) ->
    @timeout(4000)
    connection = new PerseidsConnection('production')
    connection.on '*', log
    connection.fetch('/meow').then (m) ->
      assert.fail("should have 404'd")
    .catch (err) ->
      assert.equal(err.status, 404)
      done()
    .catch done



