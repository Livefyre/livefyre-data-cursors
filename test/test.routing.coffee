{OriginRouter, ClientsideRouter, BaseSelector, RandomSelector, ConsistentSelector} = require("../lib/backends/routing.coffee")
{Promise} = require 'es6-promise'
assert = require('chai').assert


describe "ConsistentSelector", ->
  it "should select"
  it "should select consistently on inputs"
  it "should consider salt"


describe "OriginRouter", ->
  it '#route should route to baseUrl', (done) ->
    s = new OriginRouter()
    s.route(null, {baseUrl: "a"}).then (res) ->
      {url, reject} = res
      assert.equal(typeof reject, 'function')
      assert.equal(url, "a")
      done()
    .catch done

  it '#route should fail if no baseUrl', (done) ->
    s = new OriginRouter()
    assert.throws () ->
      s.route(null, {})
    done()

  it 'reject callback should do nothing', (done) ->
    s = new OriginRouter()
    s.route(null, {baseUrl: "a"}).then (res) ->
      {url, reject} = res
      reject()
      return s.route(null, {baseUrl: "a"})
    .then (res) ->
      {url, reject} = res
      assert.equal(url, "a")
      done()
    .catch done


class First extends BaseSelector
  choose: -> 0


describe "ClientsideRouter", ->
  first = First

  it '#constructor should fail if not provided a function', (done) ->
    assert.throws () ->
      s = new ClientsideRouter()
    done()

  it '#route should route with one server', (done) ->
    s = new ClientsideRouter(RandomSelector)
    conn = {
      getServers: () ->
        return Promise.resolve(['a'])
    }
    cursor = {
      meter: {}
      emit: -> 1
    }
    s.route(cursor, conn).then (res) ->
      {url} = res
      assert.equal(url, 'a')
      done()
    .catch done

  it '#route should provide a consistent result after picking a server', (done) ->
    s = new ClientsideRouter(RandomSelector)
    conn = {
      getServers: () ->
        return Promise.resolve(['a', 'b', 'c'])
    }
    cursor = {
      meter: {}
      emit: -> 1
    }

    picked = null
    s.route(cursor, conn).then (server) ->
      picked = server
      return s.route(cursor, conn)
    .then (server) ->
      assert.equal(server, picked)
      done()
    .catch done


  it '#route should route deterministically between two servers', (done) ->
    s = new ClientsideRouter(First)
    conn = {
      getServers: () ->
        return Promise.resolve(['a', 'b'])
    }
    cursor = {
      meter: {}
      emit: -> 1
    }
    s.route(cursor, conn).then (server) =>
      assert.equal(server.url, 'a')
      return s.route(cursor, conn)
    .then (server) ->
      # it should reuse
      assert.equal(server.url, 'a')
      server.reject()
      return s.route(cursor, conn)
    .then (server) ->
      assert.equal(server.url, 'b')
      server.reject()
      return s.route(cursor, conn)
    .then (server) ->
      assert.equal(server.url, 'a')
      done()
    .catch done

  it '#route should move after too many sequential errors', (done) ->
    s = new ClientsideRouter(First, 2)
    conn = {
      getServers: () ->
        return Promise.resolve(['a', 'b'])
    }
    cursor = {
      meter: {seqErrors: 0}
      emit: -> 1
    }
    s.route(cursor, conn).then (server) ->
      assert.equal(server.url, 'a')
      cursor.meter.seqErrors = 1
      return s.route(cursor, conn)
    .then (server) ->
      # it should reuse still
      assert.equal(server.url, 'a')
      cursor.meter.seqErrors = 2
      return s.route(cursor, conn)
    .then (server) ->
      # now it should have moved
      assert.equal(server.url, 'b')
      done()
    .catch done

  # to avoid the last-man-standing problem.
  it '#route should refresh servers list when below min threshold'
