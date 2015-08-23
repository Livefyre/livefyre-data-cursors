ConnectionFactory = require("../../lib/backends/factory.coffee")
assert = require('chai').assert

log = console.log.bind(console)


describe 'LivecountConnection vs production', ->

  it "should route", (done) ->
    connection = ConnectionFactory('production', {}).livecount()
    connection.on '*', log
    connection.fetch null, "/livecountping/0/0/", {}, (result) ->
      assert.equal(result.err, null)
      assert.equal(result.data.code, 302)
      done()
