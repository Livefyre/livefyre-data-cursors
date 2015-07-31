{EventEmitter} = require 'events'

#
#
#
class GrowlStream extends EventEmitter
  constructor: (@cursor) ->
    @cursor.on 'readable', (event) =>
      @emit 'readable', event

  read: (opts={}) ->
    return @cursor.read(opts)

  count: ->
    return {
      count: @cursor.status()
      estimated: false
    }

  close: ->
    @cursor.close()

  save: ->

  @restore: ->
