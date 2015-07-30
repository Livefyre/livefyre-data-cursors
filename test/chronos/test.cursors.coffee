assert = require 'assert'
fs = require 'fs'
{ChronosCursor, UnreadCursor, RecentCursor} = require '../../lib/backends/chronos/cursors.coffee'
{ChronosConnection} = require '../../lib/backends/chronos/connection.coffee'
sinon = require 'sinon'


describe.skip 'ChronosCursor init', sinon.test ->
  it "requires the client to have a fetch method", ->
    assert.equal(typeof (new ChronosConnection(null, {urn: 1}).fetch), "function")

  it 'should not work without a urn', ->
    opts = {}
    try
      new ChronosCursor(null, opts)
      assert.ifError("should have failed")
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
  c = new ChronosCursor(null, {resource: "urn:1"})
  method = c._processResponse.bind(c)
  c.on 'error', ->
    console.log arguments
  it "should propagate errors", ->
    spy = sinon.spy()
    c.once 'error', spy
    args = {err: "bad things"}
    method args...
    assert(spy.calledWith("bad things"))

  it "should barf on bad data with good exception", ->
    spy = sinon.spy()
    c.once 'error', spy
    args = {err: null, data: {meow: 1}}
    method args..., spy
    assert(spy.called)

  it "should reassign cursor, and send data including cursor", ->
    spy = sinon.spy()
    args = {err: null, data: {data: ["data"], meta: {cursor: 1}}}
    method args...
    assert.equal(c.cursor, args[2].meta.cursor)
    #assert.equal(spy.getCall(0).args[1].data, args[2].data)
    #assert.equal(spy.getCall(0).args[1].cursor, args[2].meta.cursor)



describe "Chronos Cursor Factories", ->
  conn = new ChronosConnection()
  describe "UnreadCursor", ->
    it "should create a new cursor", ->
      c = UnreadCursor(conn, "urn:...", 1)
      assert.ok(c?)
      assert.equal(c.query.resource, "urn:...")

  describe "RecentCursor", ->
    it "should create a new cursor", ->
      c = RecentCursor(conn, "urn:foo", 1)
      assert.ok(c?)
      assert.equal(c.query.resource, "urn:foo")

