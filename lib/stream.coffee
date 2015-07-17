StreamConnection = require 'livefyre-stream-client'
{EventEmitter} = require 'events'


class StreamClient extends EventEmitter
  constructor: (@environment='production') ->
    @stream = null
    @token = null
    @cursors = []
    @_connected = false

  auth: (@token) ->

  openCursor: (urn) ->
    c = new StreamCursor(this, urn, @_subscribe urn)
    @_event 'newCursor', c
    @cursors.push(c)
    return c

  closeCursor: (c) ->
    @cursors.remove(c)
    try
      subscription = c.subscription
      subscription.close()
    catch e
      @_event('error', "Failed closing subscription for #{@urn}. Error: #{e}", e)

  _subscribe: (urn) ->
    @connect()
    subscription = stream.subscribe(urn)
    return subscription

  connect: ->
    if @_connected
      return
    @_connected = true
    @stream = new StreamConnection(environment: @environment)
    if @token?
      stream.auth @token
      @_event 'authenticated'

  disconnect: () ->
    for c in @cursors
      try
        c.close()
      catch e
    try
      @stream.disconnect()
    catch e
    @_event 'disconnect'

  close: ->
    @disconnect()

  _event: (args...) ->
    @emit.apply(this, args)
    args.unshift('*')
    @emit.apply(this, args)


class StreamCursor extends EventEmitter
  constructor: (@client, @urn, @subscription) ->
    @buffer = []
    @_callback = null

    @on 'data', (data) =>
      if @_callback?
        @_callback(null, data)
        # clear the callback so that we start buffering again until asked for moar data.
        @_callback = null
      if @buffer?
        @buffer = @buffer.concat(data)
        return

  open: ->
    @subscription.on 'data', (data) =>
      if typeof data is 'string'
        data = JSON.parse(data)
      @client._event 'data', @urn, data
      @emit 'data', data

  onData: (callback) ->
    @on 'data', callback

  hasNext: () ->
    return @bufferedCount() > 0

  bufferedCount: () ->
    return if @buffer? then @buffer.length else 0

  next: (callback) ->
# The following would be how to do it if we were subject to race conditions, but
# browsers and nodejs proportedly don't have them.
# b = @buffer
# @buffer = []

    b = @buffer.splice(0, @buffer.length)
    if b.length
      callback null, b
    @_callback = callback

  close: ->
    @client.closeCursor(this)

  disableBuffer: () ->
    @buffer = null


module.exports =
  StreamClient: StreamClient
  StreamCursor: StreamCursor