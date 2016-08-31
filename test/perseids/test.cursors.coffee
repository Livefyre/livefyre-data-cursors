{PerseidsConnection} = require("../../lib/backends/perseids/connection.coffee")
_cursors = require("../../lib/backends/perseids/cursors.coffee")
{PressureRegulator} = require("../../lib/backends/flow.coffee")
{AwaitQuery, PerseidsCursor} = _cursors
{CycleDetector} = _cursors._private
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




describe "PerseidsCursor", ->
  EVTS = {
    'error': {errors: 1, seqErrors: 1}
    'timeout': {timeouts: 1, seqTimeouts: 1}
    'duplicate': {duplicates: 1}
    'backoff': {backoff: 50} # special
  }
  for event in Object.keys(EVTS)
    ((evt) ->
      it "should capture metrics for #{evt}", ->
        c = new PerseidsCursor
        c.emit evt, 1
        assert.deepEqual(c.meter.collect({}), EVTS[evt])
    )(event)

  it "event <received> should not buffer if buffer provided", (done) ->
    c = new PerseidsCursor(null, null, buffer: [])
    c.on 'readable', -> done()
    c.emit 'received', {value: 1}
    assert.equal(c.buffer.length, 1)

  it "event <received> should not buffer when no buffer provided", ->
    c = new PerseidsCursor
    c.emit 'received'
    assert.equal(c.buffer?.length, undefined)

  it "#emit should emit to *", (done) ->
    c = new PerseidsCursor
    c.once "*", -> done()
    c.emit('cow')

  it "#hasNext should proxy the query", ->
    c = new PerseidsCursor(null, hasNext: -> 'meow')
    assert.equal(c.hasNext(), 'meow')

  it "#read of no buffer yields empty array", ->
    c = new PerseidsCursor
    c.buffer = []
    assert.deepEqual(c.read(), [])

  it "#read should read destructively", ->
    c = new PerseidsCursor
    c.buffer = [1, 2]
    assert.deepEqual(c.read(), [1, 2])
    assert.deepEqual(c.read(), [])

  it "#should read with a specified size", ->
    c = new PerseidsCursor
    c.buffer = [1, 2]
    assert.deepEqual(c.read(size: 1), [1])

  it "#close should emit when closed", (done) ->
    c = new PerseidsCursor
    c.once 'closed', done
    c.close()

  it "#interrupt should interrupt the backoff process", (done) ->
    @timeout 5
    c = new PerseidsCursor
    backoff = new PressureRegulator()
    backoff.pause(cursor: c, duration: 1000).then done
    setTimeout () ->
      c.interrupt()
    , 1

  it "#sleep should update backoff", ->
    c = new PerseidsCursor
    orig = c.regulator.current()
    c.sleep(101)
    assert.equal(c.regulator.current(), 101 + orig)

  it "#wakeUp should interrupt, and reset", (done) ->
    @timeout 5
    c = new PerseidsCursor
    current = ->
      c.regulator.current()

    orig = current()
    c.regulator.hardBackoff()
    assert.equal(current(), PressureRegulator::HARD_BACKOFF)
    c._pause().then () ->
      assert.equal(current(), orig)
      done()
    .catch done

    setTimeout () ->
      c.wakeUp()
    , 1

  it "should support .resume"
  it "should support .backoff"
  it "should support server directives for throttling"




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

    
