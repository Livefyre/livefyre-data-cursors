{LiveStream, UnreadCursor} = require '../cursors.coffee'
{EventEmitter} = require 'events'

class GrowlDatasource extends EventEmitter
  constructor: (streamConnection, @urn) ->
    @cursor = LiveStream(streamConnection, @urn)
    @_buffer = []
    @cursor.on 'ready', (data) =>
      @emit 'ready', {
        source: this,
        buffered: @bufferedCount()
        newItems: data
      }

  read: (max=null) ->
    if not max? or @_buffer.length < max
      # if we know we'll undershoot max (or we're reading all),
      # go ahead and read all the queued stream items into our buffer
      @_buffer.unshift(@cursor.next()...)
    return rslice(@_buffer, max)

  bufferedCount: ->
    return {count: @cursor.bufferedCount() + @_buffer.length, estimated: false}

  close: ->
    @cursor.close()

  save: ->

  @restore: ->


class BeaconDatasource extends EventEmtter
  constructor: (chronosConnection, streamConnection, @urn, @lastRead, @limit=20) ->
    @stream = LiveStream(streamConnection, @urn)
    @unreadCursor = null
    @_buffer = []
    @_initialized = false

    # only emit updates when we've loaded from chronos
    @stream.on 'ready', (data) =>
      if not @_initialized?
        return
      @_updated()

    @unreadCursor = UnreadCursor(chronosConnection, @urn, @lastRead, limit=@limit)

    @unreadCursor.next (err, res) =>
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
    # reorder, because it came to us in ascending order,
    # and we want the youngest at the top
    data.reverse()
    @_buffer.push(data...)
    # we're official!

    # now add a marker into the  if there is more
    if cursor.hasNext()
      @_buffer.unshift(Infinity) # TODO: what should I do here.

    @_updated()

  _updated: ->
    @emit 'updated', @bufferedCount()

  bufferedCount: ->
    # don't return a count until we've
    if not @_initialized?
      return {count: NaN, estimated: true}
    return {
      count: @bufferedCount()
      estimated: @unreadCursor.hasNext()
    }

  read: (max=null) ->
    if not max? or @_buffer.length < max
      # if we know we'll undershoot max (or we're reading all),
      # go ahead and read all the queued stream items into our buffer
      @_buffer.unshift(@stream.next()...)
    return rslice(@_buffer, max)

  if max?
      assert.equal(typeof max, 'number')
      assert.ok(max > 0)
      b = []
      offset = Math.max(@_buffer.length - max, 0)
      b.unshift(@_buffer.slice(offset, max)...)
      max -= b.length
      if max <= 0
        return b
    else
      [b, @_buffer] = [@_buffer, []]

    if @unreadCursor.hasNext()
      b.unshift(Infinity) # TODO: what should I do here.
    if @stream.hasNext()
      streamed = @stream.next()
      if max?
        offset = Math.max(streamed.length - max)
        b.unshift(streamed.slice(offset, max)...)
      else
        b.unshift(streamed...)
    return b

  flush: ->
    return @read()

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
