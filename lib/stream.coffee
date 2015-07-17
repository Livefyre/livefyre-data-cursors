StreamBackend = require 'livefyre-stream-client'
{EventEmitter} = require 'events'
assert = require 'assert'


class StreamConnection extends EventEmitter
  constructor: (@environment='production') ->
    @stream = null
    @token = null
    @cursors = []

    # because we don't want everything to fail on an error
    # if nobody is listening.
    @on 'error', ->

  auth: (@token) ->

  openCursor: (opts) ->
    {urn} = opts
    assert(urn?, "Invalid/missing urn in opts")
    c = new StreamCursor(this, opts, @_subscribe urn)
    @cursors.push(c)
    @emit 'newCursor', c
    return c

  closeCursor: (c) ->
    @cursors.remove(c)
    try
      subscription = c.subscription
      subscription.close()
    catch e
      @emit('error', "Failed closing subscription for #{c.urn}. Error: #{e}", e)

  _subscribe: (urn) ->
    subscription = @connect().subscribe(urn)
    return subscription

  connect: ->
    if @stream?
      return @stream
    @stream = new StreamBackend(environment: @environment)
    if @token?
      stream.auth @token
      @emit 'authenticated'
    return @stream

  disconnect: () ->
    for c in @cursors
      try
        c.close()
      catch e
    try
      @stream.disconnect()
    catch e

    @stream = null
    @emit 'disconnect'

  close: ->
    @disconnect()

  _emit: EventEmitter::emit

  emit: (args...) ->
    @_emit.apply(this, args)
    args.unshift('*')
    @_emit.apply(this, args)




module.exports =
  StreamConnection: StreamConnection
