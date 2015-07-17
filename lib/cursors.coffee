assert = require 'assert'
{EventEmitter} = require 'events'

module.exports = exports = {}


class ChronosCursor
  constructor: (@client, opts={}) ->
    {@urn, @start, @order, @limit, @cursor} = opts
    assert.ok @urn, "invalid instantiation without valid opts.urn value"
    @start ?= null
    @order ?= -1
    @limit ?= 20
    @cursor ?= null

  hasNext: () ->
    if @order is -1
      return if @cursor then @cursor.hasPrev else true
    return if @cursor then @cursor.hasNext else true

  next: (callback) ->
    assert(callback?)
    if not @hasNext()
      callback null, []
      return

    @client.fetch @_query(), (args...) ->
      @_onResponse(args..., callback)

  _onResponse: (err, res, data, callback) ->
    assert(callback?)
    if err?
      return callback err

    if not data.meta? or not data.meta.cursor?
      return callback new DataError("invalid .meta field", data)

    @cursor = data.meta.cursor
    callback err, {data: data.data, cursor: data.meta.cursor}

  _query: () ->
    opts =
      resource: @urn
      limit: @limit
    # TODO: figure this out...
    if @order is -1
      # backward
      opts.until = if @cursor then @cursor.prev else @start
    else if @order is 1
      opts.since = if @cursor then @cursor.next else @start
    else
      throw new Error("Invalid order value: #{@order}")
    return opts


class StreamCursor extends EventEmitter
  EVENT_READY: 'ready'
  EVENT_DATA: 'data'

  constructor: (@connection, opts, @subscription) ->
    {@buffer, @filter} = @opts
    @buffer ?= []
    if @buffer is true
      @buffer = []
    @filter ?= (arg) -> return arg
    assert.equal(typeof @filter, 'function', 'filter is not a function')
    assert.ok(@buffer is null or Array.isArray(@buffer), 'invalid value for buffer')

    # propogate errors to the connection
    @on 'error', (err) ->
      @connection.emit 'error', {cursor: this, err: err}

    # awaiter
    @_awaiter = null
    @subscription.on 'data', (data) =>
      try
        @_onData(this)
      catch e
        @on 'error', new DataError("#{e}", data)

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
    if @_awaiter?
      @_awaiter(data, raw)
      return
    if @buffer?
      @buffer.unshift(data...)
      @emit @EVENT_READY, data
    else
      @emit @EVENT_DATA, data

  hasNext: () ->
    return @bufferedCount() > 0

  bufferedCount: () ->
    return if @buffer? then @buffer.length else 0

  next: (callback=null) ->
    b = @buffer.splice(0, @buffer.length)

    if not callback?
      return b
    if b.length
      callback b
    @_awaiter = callback

  close: ->
    @connection.closeCursor(this)


exports.ChronosCursor = ChronosCursor
exports.StreamCursor = StreamCursor


exports.RecentCursor = RecentCursor = (chronosConnection, urn, limit=20) ->
  opts =
    urn: urn
    query:
      lte: new Date().toISOString()
      order: 'desc'
      limit: limit
  return chronosConnection.openCursor(opts)

# Creates a cursor from latest unread to oldest unread:
#  NOW
#   |
#   | ----->
#   |
#   |
exports.UnreadCursor = UnreadCursor = (chronosConnection, urn, lastReadNext, limit=20) ->
  opts =
    urn: urn
    query:
      gt: lastReadNext
      lt: new Date().toISOString()
      order: 'desc'
      limit: limit
  return chronosConnection.openCursor(opts)


exports.ReadCursor = (chronosConnection, urn, lastReadPrev, limit=20) ->
  opts =
    urn: urn
    query:
      gte: lastReadPrev
      order: 'desc'
      limit: limit
  return chronosConnection.openCursor(opts)


exports.LiveStream = LiveStream = (streamConnection, opts) ->
  return streamConnection.openCursor(opts)


class DataError extends Error
  constructor: (@message, @data) ->
    @name = "DataError"

