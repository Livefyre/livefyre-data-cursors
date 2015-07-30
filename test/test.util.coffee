chai = require 'chai'
assert = require 'assert'
util = require '../lib/util.coffee'


describe 'User URN from Token', ->
  token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJkaXNwbGF5TmFtZSI6IjEyMzQ1Njc4OTAiLCJkb21haW4iOiJmb28uZnlyZS5jbyIsInVzZXJfaWQiOiJtZW93IDEifQ.73yKiuwxi-7Ue54Qc0Mk1qfIhCkLrZXYcxr3BowVU98'
  it 'should work', ->
    assert.equal util.getUserUrnFromToken(token), 'urn:livefyre:foo.fyre.co:user=meow%201'
