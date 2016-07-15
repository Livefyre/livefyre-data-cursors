{PerseidsConnection} = require("../../lib/backends/perseids/connection.coffee")
_cursors = require("../../lib/backends/perseids/cursors.coffee")
{AwaitQuery, PerseidsCursor, ProgressiveBackoff} = _cursors
{BasicRoutingStrategy, DSRRoutingStrategy} = _cursors
{CycleDetector, ConsistentHasher} = _cursors
{Promise} = require 'es6-promise'
assert = require('chai').assert

log = (args...) ->
  console.log('----------------------vvvvv')
  console.log(args)
  console.log('----------------------^^^^^')

describe "CycleDetector", ->
  it "should not notice new items"
  it "should notice recent cycles"
  it "should notice old cycles"
  it "should forget"
  it "should provide a max"

describe "ConsistentHasher", ->
  it "should select"
  it "should select consistently on inputs"
  it "should consider salt"

describe "PerseidsCursor", ->
  it "should capture metrics"
  it "should handle buffering"
  it "should not buffer when no buffer provided"
  it "should emit to *"
  it "should proxy hasNext"
  it "should read destructively"
  it "should read with a specified size"

  it "#close should emit when closed", (done) ->
    c = new PerseidsCursor
    c.once 'closed', done
    c.close()

  it "should support coming back to life from backoff without a new promise"
  it "should support .pause"
  it "should support .resume"
  it "should support .backoff"
  it "should support server directives for throttling"


describe "BasicRoutingStrategy", ->
  it '#route should route to baseUrl', (done) ->
    s = new BasicRoutingStrategy()
    s.route(null, {baseUrl: "a"}).then (url) ->
      assert.equal(url, "a")
      done()
    .catch done

  it '#route should fail if no baseUrl', (done) ->
    s = new BasicRoutingStrategy()
    assert.throws () ->
      s.route(null, {})
    done()


describe "DSRRoutingStrategy", ->
  first = (list) -> 0

  it '#constructor should fail if not provided a function', (done) ->
    assert.throws () ->
      s = new DSRRoutingStrategy()
    done()

  it '#route should route with one server', (done) ->
    s = new DSRRoutingStrategy(DSRRoutingStrategy::RANDOM_SELECTOR)
    conn = {
      getServers: () ->
        return Promise.resolve(['a'])
    }
    s.route({meter: {}}, conn).then (server) ->
      assert.equal(server, 'a')
      done()
    .catch done

  it '#route should provide a consistent result after picking a server', (done) ->
    s = new DSRRoutingStrategy(DSRRoutingStrategy::RANDOM_SELECTOR)
    conn = {
      getServers: () ->
        return Promise.resolve(['a', 'b', 'c'])
    }
    picked = null
    s.route({meter: {}}, conn).then (server) ->
      picked = server
      return s.route({meter: {}}, conn)
    .then (server) ->
      assert.equal(server, picked)
      done()
    .catch done


  it '#route should route deterministically between two servers', (done) ->
    s = new DSRRoutingStrategy(first)
    conn = {
      getServers: () ->
        return Promise.resolve(['a', 'b'])
    }
    s.route({meter: {}}, conn).then (server) =>
      assert.equal(server, 'a')
      return s.route(meter: {}, conn)
    .then (server) ->
      # it should reuse
      assert.equal(server, 'a')
      s.move = true
      return s.route({meter: {}}, conn)
    .then (server) ->
      assert.equal(server, 'b')
      s.move = true
      return s.route(meter: {}, conn)
    .then (server) ->
      assert.equal(server, 'a')
      done()
    .catch done

  it '#route should move after too many sequential errors', (done) ->
    s = new DSRRoutingStrategy(first, 2)
    conn = {
      getServers: () ->
        return Promise.resolve(['a', 'b'])
    }
    s.route(meter: {seqErrors: 0}, conn).then (server) ->
      assert.equal(server, 'a')
      return s.route(meter: {seqErrors: 1}, conn)
    .then (server) ->
      # it should reuse still
      assert.equal(server, 'a')
      return s.route(meter: {seqErrors: 2}, conn)
    .then (server) ->
      # now it should have moved
      assert.equal(server, 'b')
      done()
    .catch done

  # to avoid the last-man-standing problem.
  it '#route should refresh servers list when below min threshold'



describe "ProgressiveBackoff", ->
  it 'should init', (done) ->
    b = new ProgressiveBackoff(pause: 1)
    assert.equal(b._pause, 1)
    done()

  it 'should .current'
  it 'should .hardBackoff'
  it 'should .slowBackoff'
  it 'should not exceed maxPause'

  it 'should add backoff', (done) ->
    b = new ProgressiveBackoff(pause: 1)
    b.slowBackoff(100)
    assert.equal(b._pause, 101)
    done()

  it 'should multiply hard', (done) ->
    b = new ProgressiveBackoff(pause: 1, jitter: 0)
    b.hardBackoff()
    assert.equal(b._pause, b.HARD_BACKOFF)
    b.hardBackoff()
    assert.equal(b._pause, b.HARD_BACKOFF * 4)
    done()

  it 'should multiply with jitter', (done) ->
    b = new ProgressiveBackoff(pause: 1, jitter: .1)
    b.hardBackoff()
    b.hardBackoff()
    assert.notEqual(b._pause, b.HARD_BACKOFF * 4)
    assert.isAtLeast(b._pause, b.HARD_BACKOFF * 4 * 0.9)
    assert.isAtMost(b._pause, b.HARD_BACKOFF * 4 * 1.1)
    done()

  it 'should reset', (done) ->
    b = new ProgressiveBackoff(pause: 1)
    b.slowBackoff(100)
    b.reset()
    assert.equal(b._pause, 1)
    done()

  it 'needs a mechanism for canceling'
  it 'needs a mechanism for coming out of sleep mode'



describe "AwaitQuery", ->
  it 'should return immediately if completed', (done) ->
    query = new AwaitQuery("a")
    query.completed = 1
    query.next({emit: ()-> 1}, {fetch: ()->1}).then (res) ->
      assert.equal(res, 1)
      done()
    .catch done


  it "should return for PING vs production", (done) ->
    @timeout(5000)
    query = new AwaitQuery("PING")
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
    .catch done

    
