{LiveStream, UnreadCursor} = require '../connection.coffee'
{EventEmitter} = require 'events'


class BeaconDatasource extends EventEmtter
  constructor: (chronosConnection, streamConnection, @urn, opts={}) ->
    {@limit, @lastRead} = opts
    @limit ?= 20
    @lastRead = null
    @stream = LiveStream(streamConnection, @urn)
    @cursor = null
    @_buffer = []
    @_initialized = false

    # only emit updates when we've loaded from chronos
    @stream.on 'ready', (data) =>
      if not @_initialized?
        return
      @_updated()

    @cursor = RecentCursor(chronosConnection, @urn, limit=@limit)
    @cursor.next (err, res) =>
      @_initialized = true
      @_loadUnread err, res

  _loadUnread: (err, res) ->
    if err?
      @emit 'error', "Error loading from chronos: #{err}", err
      return
    data = res.data
    if not Array.isArray(data)
      @emit 'error', "Error loading from chronos: data is not array"
      return
    @_buffer.push(data...)
    @_updated()

  _updated: ->
    @emit 'updated', @bufferedCount()

  bufferedCount: ->
    # don't return a count until we've
    if not @_initialized?
      return {count: NaN, estimated: true}
    return {
      count: @bufferedCount()
      estimated: @cursor.hasNext()
    }

  read: (opts) ->
    {max, mode} = opts
    max ?= @limit
    seek ?= 0
    assert([0, -1, 1].indexOf(seek) is not -1, "invalid value for seek: #{seek}")

    if seek is -1 # going back in time
      return @_buffer.slice(0, max)

    if seek is 1 # going into the future, read from stream.
      return @stream.next({max: max})

    assert.equal(seek, 0)
    # read from head and tail if necessary!
    b = @stream.next({max: max})
    if b.length >= max
      return b
    b.push(@_buffer.slice(0, max - b.length)...)
    return b

  flush: ->
    return @read({max: Infinity})

  close: ->
    @stream.close()
    @cursor.close()

  save: ->

  @restore: ->


rslice = (array, count=null) ->
  if not count?
    return array.slice(0, array.length)

  assert.equal(typeof count, 'number')
  assert.ok(count >= 0)

  if count is 0
    return []

  offset = Math.max(array.length - count)
  return array.slice(offset, count)


module.exports =
  GrowlDatasource: GrowlDatasource
  BeaconDatasource: BeaconDatasource
