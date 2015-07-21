{EventEmitter} = require 'events'
{Precondition} = require '../../errors.coffee'


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
        @_onData(this)
      catch e
        return @on 'error', new DataError("#{e}", data)
      @emit 'readable', {size: @buffer.length}

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

  hasNext: () ->
    return bufferSize() > 0

  bufferSize: () ->
    return @buffer.length

  read: (opts={}) ->
    {size} = opts
    size ?= Infinity
    return @buffer.splice(0, size)
    # TODO add promise support

  close: ->
    @connection.closeCursor(this)


LiveStream = (streamConnection, opts) ->
  return streamConnection.openCursor(opts)


module.exports =
  StreamCursor: StreamCursor
  LiveStream: LiveStream



