{EventEmitter} = require 'events'
{Precondition} = require '../../errors.coffee'
Promise = require 'promise'


###*
  A cursor for paging through Livecount data.

  @event LivecountCursor#error
  @event LivecountCursor#readable
  @event LivecountCursor#end

###
class LivecountCursor extends EventEmitter
  constructor: (@connection, @query) ->
    @_route = @_getRoute()
    @_live = false
    @buffer = []
    @on 'error', (args...) ->
    @_nextScheduled = null
    @next()

  hasNext: ->
    return true

  count: ->
    return @buffer.length

  read: (opts={}) ->
    {size} = opts
    size ?= Infinity
    Precondition.checkArgumentType(size, 'number')
    return @buffer.splice(0, size)

  next: ->
    if @_nextScheduled
      return

    getRoute().then (url) ->
      if not url
        @_live = false
        @emit 'end'
        return
      [path, params] = @query.buildPathAndQuery(this, true)
      @connection.fetch url, path, params, (result) =>
        try
          @_processResponse(result)
        catch err
          @emit 'error', err
        if err?
          @_live = false
          return
        Precondition.checkArgumentType(result.data, 'number', "invalid data: #{result}")
        @buffer.push(result.data)
        @emit 'readable', {
          buffered: @buffer.length
          liveCount: result.data
        }
        @_rescheduleNext()

  getRoute: ->
    return Promise.resolve(@_route)

  _rescheduleNext: ->
    setTimeout(@next.bind(this), @_interval)

  _getRoute: ->
    [path, params] = @query.buildPathAndQuery(this, false)
    p = Promise.denodeify(@connection.fetch.bind(@connection))(null, path, params)
      .then (res) =>
        @emit 'routeinfo', res.body
        Precondition.checkArgumentType(res.body.url, 'string')
        return res.body.url
      .catch (err) =>
        @emit 'error', err
        return null
    return p

  close: ->
    @_closed = true

  isLive: ->
    return true

  fault: ->

  next: ->
    # are we already fetching?
    if @_running
      console.log("running...")
      return
    console.log("fetching...")
    @_running = true
    @connection.fetch @query.buildPathAndQuery()..., (result) =>
      console.log("receiving...")
      try
        if @_closed
          return
        @_running = false
        @_processResponse(result)
      catch err
        @_errors++
        @_backoff 4
        @emit 'error', err
      finally
        if @stream and not @_closed
          console.log("Streaming in #{this._pause}ms")
          setTimeout(@next.bind(this), @_pause)

  _processResponse: (result) ->
    # handle errors
    if result.err?
      throw result.err
    payload = result.data
    Precondition.checkArgument(payload?, true, "fetched data has no .data!")

    # handle timeouts
    if payload.timeout? and payload.timeout
      @_timeouts++
      @query.onTimeout(payload, @_timeouts)
      @_parked = payload.parked
      @emit 'timeout', payload
      if @timeouts > @backoffAfterNTimeouts
        @backoff 2
      return

    # clear any backoff
    @_pause = @pauseNMsBetweenRequests
    @_timeouts = 0

    data = payload.data
    Precondition.checkArgument(data?, true, "fetched data has no .data!")
    # @emit 'duplicate', eventId
    data = @query.update(data)

    delta = undefined
    if data?
      @buffer.push(data)
      if data.maxEventId?
        delta = @connection.getServerAdjustedTime().getTime() - (data.maxEventId / 1000)

    @emit 'readable', {
      buffered: @buffer.length
      data: data
      isDone: false
      delta: delta
    }
    @emit 'end' if not @hasNext()



class CollectionLivecountQuery
  constructor: (@resource, @interval=30 * 1000) ->
    Precondition.checkArgumentType(@resource, 'string', "invalid resource value: #{@resource}")
    Precondition.checkArgument(@resource.indexOf('urn:') == 0, true,
      "invalid query.resource value; expected URN, got: #{@resource}")
    Precondition.checkArgument(@resource.indexOf('collection=') > 0, true,
      "invalid query.resource value; expected collection URN, got: #{@resource}")

    @collectionId = decodeURIComponent(@resource.split(/collection=/)[1])

  buildPathAndQuery: (cursor, routed) ->
    userHash = "0"
    path = "/livecountping/#{@collectionId}/#{userHash}/"
    if routed
      params = {routed: 1, _: Math.random()}
    else
      params = {_: Math.random()}
    return [path, params]


module.exports =
  LivecountCursor: LivecountCursor
  CollectionLivecountQuery: CollectionLivecountQuery
