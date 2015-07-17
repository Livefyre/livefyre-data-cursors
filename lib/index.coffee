clients = require './chronos.coffee'
{EventEmitter} = require 'events'

class Drivers
  instance = null

  constructor: (@environment) ->
    instance = this
    @stream = new (clients.StreamClient)(@environment)
    @chronos = new (clients.ChronosClient)(@environment)

  auth: (token) ->
    @stream.auth @token
    @chronos.auth @token


LiveStream = (stream, @urn) ->
  return stream.cursor(@urn)


RecentCursor = (chronos, @urn, size=20) ->
  opts =
    lte: new Date().toISOString()
    order: 'desc'
    limit: size
  return chronos.cursor(@urn, opts)


UnreadCursor = (chronos, @urn, lastRead, size=20) ->
  opts =
    gt: lastRead
    order: 'asc'
    limit: size
  return chronos.cursor(@urn, opts)


ReadCursor = (chronos, @urn, lastRead, size=20) ->
  opts =
    gte: lastRead
    order: 'desc'
    limit: size
  return chronos.cursor(@urn, opts)


class GrowlDatasource
  constructor: (drivers, urn, opts={}) ->
    @cursor = LiveStream(drivers.stream, urn)

  get: (callback) ->
    @cursor.next callback

  count: ->
    return @cursor.bufferedCount()

  close: () ->
    @cursor.close()


class BeaconDatasource
  EVENT_STATE_CHANGE: 'stateChange'
  EVENT_DATA_RECEIVED: 'data'
  EVENT_ERROR: 'error'

  _0: 0
  _LOADING: 1
  _LOADED: 2
  _STREAMING: 3

  constructor: (drivers, urn, @lastRead, initial=20) ->
    @streamCursor = LiveStream(drivers.stream, urn)
    @unreadCursor = UnreadCursor(drivers.chronos, urn, lastRead, initial)
    @_count = NaN
    @_estimated = null
    @_state = @_0
    @_emitter = new EventEmitter

    @streamCursor.onData @_onStreamData.bind(this)

  on: (event, callback) ->
    @_emitter.on event, callback

  # return the current counts, and if it's estimated or not, as a
  # datastructure:
  #   count: {NaN | posint}
  #   estimated: {bool}
  getCount: ->
    if @_count is NaN
      return {count: NaN, estimated: true}
    return {
      count: @_count + @streamCursor.bufferedCount()
      estimated: @_estimated
    }

  # ask to read more data; the caller should have registered
  #   via `.on(BeaconDatasource.EVENT_DATA_RECEIVED, callback)`
  read: ->
    switch @_state
      # we need to fetch the first batch of unread:
      when @_0 then @_loadInitial()
      # we are waiting for the first batch of unread,
      # so there's nothing more to read, yet.
      when @_LOADING then return
      when @_LOADED then @_readStream()
      when @_STREAMING then return

  seek: (direction=1) ->
    switch @_state
      when @_0 then @read()
      when @_LOADED then @_seek(direction)
      when @_STREAMING then @_seek(direction)

  _seek: (direction) ->
    switch (direction)
      # advance
      when 1 then @_seekForward()
      when -1 then @_seekBackward()

  _seekForward: ->
    # Usecase
    if not @unreadCursor.hasNext()
      @_estimated = false
      @_add(0)
      return
    @unreadCursor.next (err, items) =>
      if err?
        return @_emit @EVENT_ERROR, err
      @_estimated = @unreadCursor.hasNext()
      return @_add(items.length, items)

  # emit events to listeners
  _emit: (event, msg) ->
    @_emitter.emit(event, msg)
    @_emitter.emit('*', event, msg)

  # update counts, emit counts and items.
  _add: (value, items=null) ->
    @_count += value
    cinfo = @getCount()
    cinfo.items = items
    @_emit(@EVENT_DATA_RECEIVED, cinfo)

  _updateState: (to) ->
    msg =
      from: @_state
      to: to
    @_emit @EVENT_STATE_CHANGE, msg

  _loadInitial: ->
    @_updateState(@_LOADING)
    @unreadCursor.next (err, items) =>
      @_updateState(@_LOADED)
      @_count = 0
      if err?
        @_emit @EVENT_ERROR, err
      if not items? or items.length == 0
        # we got no data unread; so we are not estimating
        @_estimated = false
        @_add(0, [])
        # go to next step: we can start streaming
        return @read()

      # if we can page forward, it means we
      # got the oldest of the unread.
      @_estimated = @unreadCursor.hasNext()
      # data! count it!
      @_add(items.length, items)

  _readStream: ->
    @_state = @_STREAMING
    @streamCursor.next (err, data) =>
      if err?
        @_emit @EVENT_ERROR, err
      if data? and data.length > 0
        @_add(data.length, data)

  _onStreamData: ->
    # We don't really care what was received; we just want to
    # emit updated counts. This way, the data is still buffered on the
    # cursor and will be available for reading.
    @_add(0)


module.exports = (environment) ->
  driver = Drivers.instance = new Drivers(environment)

  exports =
    Drivers: driver


class LiveTimeline
  constructor: (@environment, @urn, @lastRead=null, @maxItems=20) ->

  auth: (@token) ->

  close: () ->
    @_stream.close()
    @_chronos.close()

  _setup: () ->

    # cursor for the head of the stream: n items up until now.
    recentOpts =
      start: new Date().toISOString()
      order: -1 # until
      limit: @maxItems
    @recentCursor = chronos.cursor(@urn, recentOpts)

    if @lastRead?
      # cursor for the tail since you last read: n items since last read, not inclusive
      unreadOpts =
        start: @lastRead
        order: 1 # since
        limit: @maxItems
      @unreadCursor = chronos.cursor(@urn, unreadOpts)
      readOpts =
        start: @lastRead # TODO offset a little!
        order: -1 # until
      @readCursor = chronos.cursor(@urn, readOpts)
    else
      @unreadCursor = null
      @readCursor = null

  load: (@callback) ->
    @_setup()
    @recentCursor.next (err, data, cursor) =>
      if err?
        return @yield err, data, cursor

      callback err, 'recent', @scrub(data), cursor
      # great, we have recent data; release the embargo on the other sources
      @streamCursor.next (err, data) ->
        callback err, 'stream', @scrub(data)
      if @unreadCursor?
        @unreadCursor.next (err, data, cursor) ->
          callback err, 'unread', @scrub(data), cursor

  isUnread: (activity) ->
    return true

  scrub: (activities) ->
    # TODO dedup, normalize
    if not activities?
      return activities
    return activities

  more: () ->
    @recentCursor.next (err, data) ->
      callback err, 'recent', @scrub(data)
