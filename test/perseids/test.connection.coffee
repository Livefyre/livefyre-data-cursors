ConnectionFactory = require("../../lib/backends/factory.coffee")
assert = require('chai').assert

log = console.log.bind(console)


describe 'PerseidsConnection vs production', ->

  it "should getServers", (done) ->
    connection = ConnectionFactory('production', {}).perseids()
    connection.on '*', log
    connection.getServers().then (list) ->
      assert.equal(list.length > 0, true, list.join(", "))
      assert.equal(list[0].indexOf('ct') == 0, true, list[0])
      assert.equal(Array.isArray(connection._cachedDsrServers), true)
      done()

  it "should handle ping", (done) ->
    connection = ConnectionFactory('production', {}).perseids()
    connection.on '*', log
    connection.fetch '/v3.1/collection/PING/0/', {}, (m) ->
      result = m.data
      assert.equal(result.code, 200)
      assert.equal(result.status, "ok")
      assert.equal(result.data.maxEventId, 1)
      done()
