assert = require 'assert'
fs = require 'fs'
{ChronosConnection} = require '../../lib/backends/chronos/cursors.coffee'

log = console.log.bind(console)


describe 'ChronosConnection should work against production', ->
