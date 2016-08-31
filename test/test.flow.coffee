{CancellationError} = require '../lib/errors.coffee'
flow = require("../lib/backends/flow.coffee")
{FlowRegulator, LinearBackoff, GeometricBackoff, Delay} = flow
assert = require('chai').assert
{equal} = assert

describe "LinearBackoff", ->
  it '#constructor(defaults)', ->
    b = new LinearBackoff
    assert.equal b.max(), b._max
    assert.equal b.current(), b.init
    b.next()
    assert.equal b.current() / 1000, b.init + b.increment
    b.reset()
    assert.equal b.current() / 1000, b.init

  it '#constructor(opts)', ->
    b = new LinearBackoff(init: 1, increment: 2, max: 4)
    assert.equal b.max(), 4
    assert.equal b.current() / 1000, 1
    b.next()
    assert.equal b.current() / 1000, 3
    b.next()
    assert.equal b.current() / 1000, 4
    b.reset()
    assert.equal b.current() / 1000, 1

  it '#constructor(jitter) should work', ->
    b = new LinearBackoff(init: 1, jitter: 0.5)
    assert.notEqual(b.current(), 1000)
    assert.isAtLeast(b.current(), 500)
    assert.isAtMost(b.current(), 1500)


describe "GeometricBackoff", ->
  it '#constructor(default)', ->
    b = new GeometricBackoff
    assert.equal b.max(), b._max
    assert.equal b.current() / 1000, 4
    b.next()
    assert.equal b.current() / 1000, 8
    b.next()
    assert.equal b.current() / 1000, 16
    b.reset()
    assert.equal b.current() / 1000, 4

  it '#constructor(opts)', ->
    b = new GeometricBackoff(max: 10, base: 3, exp: 1)
    assert.equal b.max(), 10
    assert.equal b.current() / 1000, 3
    b.next()
    assert.equal b.current() / 1000, 9
    b.next()
    assert.equal b.current() / 1000, 10
    b.reset()
    assert.equal b.current() / 1000, 3


describe "Delay", ->
  it '#constructor(LinearBackoff, 0)', ->
    l = new LinearBackoff
    b = new Delay(l, 0)
    assert.equal b.max(), l.max()
    assert.equal b.current(), l.init
    b.next()
    assert.equal b.current() / 1000, l.init + l.increment
    b.reset()
    assert.equal b.current() / 1000, l.init

  it '#constructor(LinearBackoff, 1) should delay one', ->
    l = new LinearBackoff
    b = new Delay(l, 1)
    assert.equal b.max(), l.max()
    assert.equal b.current(), l.init
    b.next()
    assert.equal b.current(), l.init
    b.next()
    assert.equal b.current() / 1000, l.init + l.increment
    b.reset()
    assert.equal b.current() / 1000, l.init


describe "FlowRegulator", ->
  it '#constructor(!object) should fail', ->
    assert.throws () ->
      new FlowRegulator()

    assert.throws () ->
      new FlowRegulator([])

    assert.throws () ->
      new FlowRegulator(1)

  it '#constructor(object) without default should fail', ->
    assert.throws () ->
      new FlowRegulator(meow: new LinearBackoff)

  it '#constructor(object) with a default state should work', ->
    l = new LinearBackoff
    f = new FlowRegulator(default: l)
    c = l.current()
    equal f.current(), l.current()
    f.backoff()
    equal f.current(), l.current()
    assert.notEqual f.current(), c
    f.release()
    equal f.current(), c

  it '#cancel with no promise should pass', ->
    f = new FlowRegulator(default: new LinearBackoff)
    equal f.cancel(), false

  it '#cancel with promise should pass', (done) ->
    f = new FlowRegulator(default: new LinearBackoff(init: 1))
    f.pause().catch (e) ->
      if e instanceof CancellationError
        done()
      else
        done(e)
    equal f.cancel(), true

  it '#interrupt without promise should pass', ->
    f = new FlowRegulator(default: new LinearBackoff(init: 1))
    f.interrupt()

  it '#interrupt with promise should pass', (done) ->
    @timeout 5
    f = new FlowRegulator(default: new LinearBackoff(init: 1))
    f.pause().then () ->
      done()
    .catch done
    setTimeout f.interrupt.bind(f), 1

  it '#pause should actually pause', (done) ->
    @timeout 10
    x = {}
    f = new FlowRegulator(default: new LinearBackoff(init: 0.005))
    f.pause().then () ->
      x.y = true
    .catch done
    setTimeout () ->
      if x.y?
        done(new Error("didn't pause"))
    , 1
    setTimeout () ->
      if x.y
        done()
      else
        done(new Error("pause never cleared"))
    , 7

  it "#pause x2 should error", (done) ->
    f = new FlowRegulator(default: new LinearBackoff(init: 0.005))
    f.pause().then () ->
      done()
    assert.throws () ->
      f.pause()

  it "#pause followed by #pause should not error", (done) ->
    f = new FlowRegulator(default: new LinearBackoff(init: 0.005))
    f.pause().then () ->
      return f.pause()
    .then () ->
      done()
    assert.throws () ->
      f.pause()

  it '#setState to same should noop', (done) ->
    f = new FlowRegulator(default: new LinearBackoff, other: new LinearBackoff)
    f.on '*', (e)->
      done(new Error("oh no"))
    f.setState 'default'
    done()

  it '#setState to different should emit an event', (done) ->
    f = new FlowRegulator(default: new LinearBackoff(init: 1), other: new LinearBackoff(init: 2))
    f.on 'stateChanged', (e) ->
      assert.deepEqual e, {
        current: 2000
        previous: 1000
        oldState: 'default'
        newState: 'other'
      }
      done()
    f.setState 'other'

  it '#setState to bogus should err', ->
    f = new FlowRegulator(default: new LinearBackoff, other: new LinearBackoff)
    assert.throws () ->
      f.setState 'moo'

  it '#setState(..., advance=true) should advance to a greater value', ->
    f = new FlowRegulator(default: new LinearBackoff(increment: 1), other: new GeometricBackoff)
    i = 0
    while i < 10
      f.backoff()
      i++
    current = f.current()
    equal current, 10000 # 10 sec
    f.setState 'other'
    equal f.current(), 16000 # 16 sec




  it 'should .current'
  it 'should .hardBackoff'
  it 'should .slowBackoff'
  it 'should not exceed maxPause'

  it 'should add backoff', (done) ->
    b = new FlowRegulator(pause: 1)
    b.slowBackoff(100)
    assert.equal(b._pause, 101)
    done()

  it 'should multiply hard', (done) ->
    b = new FlowRegulator(pause: 1, jitter: 0)
    b.hardBackoff()
    assert.equal(b._pause, b.HARD_BACKOFF)
    b.hardBackoff()
    assert.equal(b._pause, b.HARD_BACKOFF * 4)
    done()

  it 'should multiply with jitter', (done) ->
    b = new FlowRegulator(pause: 1, jitter: .1)
    b.hardBackoff()
    b.hardBackoff()
    assert.notEqual(b._pause, b.HARD_BACKOFF * 4)
    assert.isAtLeast(b._pause, b.HARD_BACKOFF * 4 * 0.9)
    assert.isAtMost(b._pause, b.HARD_BACKOFF * 4 * 1.1)
    done()

  it 'should reset', (done) ->
    b = new FlowRegulator(pause: 1)
    b.slowBackoff(100)
    b.reset()
    assert.equal(b._pause, 1)
    done()

  it 'needs a mechanism for canceling'
  it 'needs a mechanism for coming out of sleep mode'

