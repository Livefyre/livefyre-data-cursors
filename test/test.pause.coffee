{Pause} = require("../lib/backends/flow.coffee")
assert = require('chai').assert

describe "Pause", ->
  it '#then should complete', (done) ->
    run = false
    new Pause(2).then ->
      run = true
    .then ->
      assert.equal run, true
    .then done
    assert.equal run, false

  it '#then should curry args', (done) ->
    p = new Pause(1, 2, 3)
    assert.deepEqual p.args, [2, 3]
    p.then (a) ->
      assert.deepEqual a, [2, 3]
      assert.equal p.state, p.RUN
      done()
    .catch done

  it '#extend(pos) should extend', (done) ->
    @timeout 20
    x = 0
    p = new Pause(1)
    p.then ->
      assert.equal x, 1
      assert.equal p.duration, 6
      done()
    .catch done
    setTimeout ->
      x++
    , 4
    p.extend 5

  it '#extend(negative) should decrease', (done) ->
    @timeout 20
    x = 0
    p = new Pause(100)
    p.then ->
      assert.equal x, 1
      assert.equal p.duration, 10
      done()
    .catch done
    setTimeout ->
      x++
    , 5
    p.extend -90

  it '#extend(<0) should run immediately', (done) ->
    @timeout 20
    x = 0
    p = new Pause(100)
    p.then ->
      assert.equal x, 0
      assert.equal p.duration, 0
      done()
    .catch done
    setTimeout ->
      x++
    , 5
    p.extend -1000
    assert.equal p.duration, 0
    assert.equal p.state, p.RUN


  it '#interrupt should trigger execution', (done) ->
    @timeout 5
    x = {}
    p = new Pause(1000)
    p.then =>
      x[1] = true
    .then =>
      assert.deepEqual x, {1: true}
      done()
    assert.deepEqual x, {}
    assert.equal p.state, Pause::PAUSED
    p.interrupt()
    assert.equal p.state, Pause::RUN

  it '#cancel fail', (done) ->
    @timeout 10
    p = new Pause(200)
    p.then =>
      done(new Error("didn't expect this"))
    .catch =>
      assert.equal p.state, Pause::CANCELLED
      done()
    assert.equal p.state, Pause::PAUSED
    assert.throws ->
      p.cancel()
    assert.equal p.state, Pause::CANCELLED

  it '#cancel raises repeatedly', (done) ->
    p = new Pause(200)
    p.catch ->
      assert.equal p.state, Pause::CANCELLED
      done()

    assert.throws ->
      p.cancel()

    assert.throws ->
      p.cancel()
