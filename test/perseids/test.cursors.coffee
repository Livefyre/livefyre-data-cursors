{PerseidsConnection} = require("../../lib/backends/perseids/connection.coffee")
{AwaitQuery, PerseidsCursor, ProgressiveBackoff} = require("../../lib/backends/perseids/cursors.coffee")
{BasicRoutingStrategy, DSRRoutingStrategy} = require("../../lib/backends/perseids/cursors.coffee")
{Promise} = require 'es6-promise'
assert = require('chai').assert

log = (args...) ->
  console.log('----------------------vvvvv')
  console.log(args)
  console.log('----------------------^^^^^')

describe "BasicRoutingStrategy", ->
  it 'should route to baseUrl', (done) ->
    s = new BasicRoutingStrategy()
    s.route(null, {baseUrl: "a"}).then (url) ->
      assert.equal(url, "a")
      done()


describe "DSRRoutingStrategy", ->
  first = (list) -> 0

  it 'should fail if not provided a function', (done) ->
    assert.throws () ->
      s = new DSRRoutingStrategy()
    done()

  it 'should route with one server', (done) ->
    s = new DSRRoutingStrategy(DSRRoutingStrategy::RANDOM_SELECTOR)
    conn = {
      getServers: () ->
        return Promise.resolve(['a'])
    }
    s.route({}, conn).then (server) ->
      assert.equal(server, 'a')
      done()
    .catch (err) ->
      throw err

  it 'should route between two servers', (done) ->
    s = new DSRRoutingStrategy(first)
    conn = {
      getServers: () ->
        return Promise.resolve(['a', 'b'])
    }
    s.route({}, conn).then (server) =>
      assert.equal(server, 'a')
      return s.route({}, conn)
    .then (server) ->
      # it should reuse
      assert.equal(server, 'a')
      s.move = true
      return s.route({}, conn)
    .then (server) ->
      assert.equal(server, 'b')
      s.move = true
      return s.route({}, conn)
    .then (server) ->
      assert.equal(server, 'a')
      done()
    .catch (err) =>
      throw err

  it 'should move after too many errors', (done) ->
    s = new DSRRoutingStrategy(first, 2)
    conn = {
      getServers: () ->
        return Promise.resolve(['a', 'b'])
    }
    s.route({seqErrors: 0}, conn).then (server) ->
      assert.equal(server, 'a')
      return s.route({seqErrors: 1}, conn)
    .then (server) ->
      # it should reuse still
      assert.equal(server, 'a')
      return s.route({seqErrors: 2}, conn)
    .then (server) ->
      # now it should have moved
      assert.equal(server, 'b')
      done()
    .catch (err) =>
      throw err



describe "ProgressiveBackoff", ->
  it 'should init', (done) ->
    b = new ProgressiveBackoff(1)
    assert.equal(b._pause, 1)
    done()

  it 'should add backoff', (done) ->
    b = new ProgressiveBackoff(1)
    b.slowBackoff(100)
    assert.equal(b._pause, 101)
    done()

  it 'should multiply hard', (done) ->
    b = new ProgressiveBackoff(1, 0)
    b.hardBackoff()
    assert.equal(b._pause, b.HARD_BACKOFF)
    b.hardBackoff()
    assert.equal(b._pause, b.HARD_BACKOFF * 4)
    done()

  it 'should multiply with jitter', (done) ->
    b = new ProgressiveBackoff(1, .1)
    b.hardBackoff()
    b.hardBackoff()
    assert.notEqual(b._pause, b.HARD_BACKOFF * 4)
    assert.isAtLeast(b._pause, b.HARD_BACKOFF * 4 * 0.9)
    assert.isAtMost(b._pause, b.HARD_BACKOFF * 4 * 1.1)
    done()

  it 'should reset', (done) ->
    b = new ProgressiveBackoff(1)
    b.slowBackoff(100)
    b.reset()
    assert.equal(b._pause, 1)
    done()



describe "AwaitQuery", ->
  it 'should return immediately if completed', (done) ->
    query = new AwaitQuery("a")
    query.completed = 1
    query.next().then (res) ->
      assert.equal(res, 1)
      done()

  it "should pick a single server.", (done) ->
    url = null
    query = new AwaitQuery("a")
    query._selectServer({}, {
      getServers: () ->
        Promise.resolve(["http://a", "http://b", "http://c"])
    }).then (res) ->
      assert.equal(query._server?, true)
      assert.equal(res.indexOf("http"), 0)
      url = res
      return query._selectServer({}, null)
    .then (res) ->
      assert.equal(res, url)
      done()
    .catch (err) ->
      log err
      throw err

  it "should return for PING vs production", (done) ->
    @timeout(5000)
    query = new AwaitQuery("PING", dsr: false)
    conn = new PerseidsConnection("production")
    cursor = new PerseidsCursor(conn, query)
    cursor.on '*', log
    conn.on '*', log
    conn.on 'error', log
    cursor.on 'error', log
    p = cursor.next()
    p.then (res) ->
      log res
      assert.equal(res.active, true)
      done()
    .catch (err) ->
      assert.failException(err)

    
