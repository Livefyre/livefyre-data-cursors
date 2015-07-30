{EventEmitter} = require 'events'
{Precondition} = require '../../errors.coffee'



#
# This is a stream.Readable-like interface. It's not a complete
# implementation, as it preserves the SQL cursor-like
# semantics and expectations for use.
#
# c = streamConnection.open({urn: "urn:..."})
# c.on 'readable', (event) ->
#   console.log("New items streamed: #{event.data}; #{event.buffered} items buffered")
#   updateView(c.read())
#
class StreamCursor extends EventEmitter

  constructor: (@connection, @subscription, opts={}) ->
    {@filter} = opts
    @buffer = [] # oldest to youngest
    @filter ?= (arg) -> return arg
    Precondition.equal(typeof @filter, 'function', 'filter is not a function')

    # propogate errors to the connection
    @on 'error', (err) ->
      @connection.emit 'error', {cursor: this, err: err}

    @subscription.on 'data', (data) =>
      try
        added = @_onData(this)
      catch e
        return @on 'error', new DataError("#{e}", data)
      if added? and added.length > 0
        @emit 'readable', {
          buffered: @buffer.length
          data: added
        }

  hasNext: ->
    return count() > 0

  count: ->
    return @buffer.length

  read: (opts={}) ->
    Precondition.equal(typeof opts, 'object')
    {size} = opts
    size ?= Infinity
    Precondition.equal(typeof size, 'number')
    return @buffer.splice(0, size)

  close: ->
    @connection.closeCursor(this)

  isLive: ->
    return @connection.isLive()

  _onData: (raw) ->
    if typeof raw is 'string'
      raw = JSON.parse(raw)
    if not Array.isArray(raw)
      raw = [raw]
    data = @filter(raw)
    if not data?
      return
    if data.length is 0
      return
    @buffer.push(data...)
    return data.length



LiveStream = (streamConnection, opts) ->
  return streamConnection.openCursor(opts)


class MockStreamCursor extends EventEmitter

  constructor: () ->
    @buffer = [] # oldest to youngest

  push: (args...) ->
    @buffer.push(args...)

  hasNext: ->
    return count() > 0

  count: ->
    return @buffer.length

  read: (opts={}) ->
    StreamCursor.read(this, opts)

  close: ->

  isLive: ->
    return true


module.exports =
  StreamCursor: StreamCursor
  LiveStream: LiveStream
  MockStreamCursor: MockStreamCursor



