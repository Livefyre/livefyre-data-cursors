assert = require 'assert'
fs = require 'fs'
{ChronosCursor, UnreadCursor, RecentCursor} = require '../lib/cursors.coffee'
{ChronosConnection} = require '../lib/chronos.coffee'
sinon = require 'sinon'


describe 'ChronosCursor init', sinon.test ->
  it "requires the client to have a fetch method", ->
    assert.equal(typeof (new ChronosConnection(null, {urn: 1}).fetch), "function")

  it 'should not work without a urn', ->
    opts = {}
    try
      new ChronosCursor(null, opts)
      assert.ifError("didn't fail")
    catch e

  it "initializes from all options", ->
    opts = {urn: "moo", order: "order", limit: "limit", cursor: "cursor", start: "start"}
    c = new ChronosCursor(null, opts)
    for key of opts
      assert.equal(c[key], opts[key])

  it "initializes from some options", ->
    opts = {urn: "moo"}
    c = new ChronosCursor(null, opts)
    for key of opts
      assert.equal(c[key], opts[key])
    assert.equal(c.limit, 20)

  it "hasNext with cursor", ->
    c = new ChronosCursor(null, {urn: 1, order: 1, cursor: {hasNext: true}})
    assert.ok c.cursor
    assert.equal(c.hasNext(), true)

  it "hasNext is false with dead cursor", ->
    c = new ChronosCursor(null, {urn: 1, order: 1, cursor: {hasNext: false}})
    assert.ok c.cursor
    assert.equal(c.hasNext(), false)


  # waiting for these until we have a new chronos contract
  queryTests =
    opt1: [{urn: 1, order: 1}, {"resource":1,"limit":20,"since":null}]

  for key of queryTests
    it.skip "builds a good query #{key}", ->
      [opts, expected] = queryTests[key]
      c = new ChronosCursor(null, opts)
      assert.deepEqual(c._query(), expected)


describe "ChronosCursor response handling", ->
  c = new ChronosCursor(null, {urn: 1})
  method = c._onResponse.bind(c)
  it "should propagate errors", ->
    spy = sinon.spy()
    args = ["bad things", null, null]
    method args..., spy
    assert(spy.calledWith("bad things"))

  it "should barf on bad data with good exception", ->
    spy = sinon.spy()
    args = [null, null, {meow: 1}]
    method args..., spy
    assert.equal(spy.getCall(0).args[0].data, args[2])

  it "should reassign cursor, and send data including cursor", ->
    spy = sinon.spy()
    args = [null, null, {data: "data", meta: {cursor: 1}}]
    method args..., spy
    assert.equal(spy.getCall(0).args[1].data, args[2].data)
    assert.equal(spy.getCall(0).args[1].cursor, args[2].meta.cursor)
    assert.equal(c.cursor, args[2].meta.cursor)


describe "Chronos Cursor Factories", ->
  conn = new ChronosConnection()
  describe "UnreadCursor", ->
    it "should create a new cursor", ->
      c = UnreadCursor(conn, "foo", 1)
      assert.ok(c?)
      assert.equal(c.urn, "foo")

  describe "RecentCursor", ->
    it "should create a new cursor", ->
      c = RecentCursor(conn, "foo", 1)
      assert.ok(c?)
      assert.equal(c.urn, "foo")

