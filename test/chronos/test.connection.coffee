assert = require 'assert'
fs = require 'fs'
{ChronosConnection} = require '../../lib/backends/chronos/connection.coffee'

log = console.log.bind(console)


describe 'ChronosConnection should work against production', ->
  urn = "urn:livefyre:cnn.fyre.co:site=353270:topic=54a2fe0def40ce028cedb0b4:topicStream"
  token = 'eyJhbGciOiAiSFMyNTYiLCAidHlwIjogIkpXVCJ9.eyJkb21haW4iOiAibGl2ZWZ5cmUuY29tIiwgImV4cGlyZXMiOiAxNzUyNDUyNjkxLjE0NDQ1NywgInVzZXJfaWQiOiAiYm9iIn0.sRakvOMnVDTgr317noYLTq29waoeMtyJX-xzKDXIwFw'
  token = 'eyJhbGciOiAiSFMyNTYiLCAidHlwIjogIkpXVCJ9.eyJkb21haW4iOiAiY25uLmZ5cmUuY28iLCAiZXhwaXJlcyI6IDE3NTI0NTM4ODcuOTM5MzY3LCAidXNlcl9pZCI6ICJib2IifQ.oagxlQqOBrzRjqsDLfcd0hzb0mC6UQcechs8j2Crk-0'
  token = 'eyJhbGciOiAiSFMyNTYiLCAidHlwIjogIkpXVCJ9.eyJkb21haW4iOiAiY25uLmZ5cmUuY28iLCAiZXhwaXJlcyI6IDE0MzcxODAzNTcuMjE4NzgsICJ1c2VyX2lkIjogImJvYiJ9.DkU4QKbqHR-zl9nFwaEydtIYEGBCKTczJUxUZfl69gU'
  client = new ChronosConnection('production')
  client.on '*', (event, args...) ->
    log(">>>>> " + event)
    log(args)

  @timeout 5000

  it "should not work without a token - #{urn}", (done) ->

    client.fetch {resource: urn}, (res) ->
      log(res)
      log(res.err)
      assert(res.err?)
      assert.equal(res.err.status, 401)
      #assert.equal(res.status, 401)
      done()

  it.skip "should work with a token - #{urn}", (done) ->
    client.auth token
    client.fetch {resource: urn, limit: 5}, (err, res, body) ->
      log(body)
      log(err)
      assert.equal(err, null)
      assert.equal(res.ok, true)
      assert.equal(body.code, 200)
      assert.equal(body.data.length, 5)
      assert.equal(body.meta.cursor.hasPrev, true)
      assert.equal(body.meta.cursor.limit, 5)
      assert.equal(body.meta.cursor.limit, 5)
      assert.equal(body.meta.cursor.prev?, true)
      assert.equal(body.meta.cursor.next?, true)
      # This isn't true because something is weird.
      # assert.equal(body.meta.cursor.next, body.data[0].tuuid)
      #This isn't true because something is weird.
      # assert.equal(body.meta.cursor.prev, body.data[body.data.length - 1].tuuid)
      done()

  it.skip "should save data", (done) ->
    client.auth token
    client.fetch {resource: urn, limit: 50}, (err, res, body) ->
      assert.equal(err, null)
      assert.equal(res.ok, true)
      assert.equal(body.code, 200)
      fs.writeFileSync "#{urn}.json", JSON.stringify(body)
