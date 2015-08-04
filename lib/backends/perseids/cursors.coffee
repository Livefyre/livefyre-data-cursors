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

  hasNext: ->

  count: ->

  read: (opts={}) ->

  close: ->

  isLive: ->


###*
  A cursor for paging through Perseids data.

  @event PerseidsCursor#error
  @event PerseidsCursor#readable
  @event PerseidsCursor#end

###
class PerseidsCursor extends EventEmitter
  constructor: (@connection, @query) ->
    Precondition.checkArgumentType(@query.resource, 'string', "invalid query.resource value: #{@query.resource}")
    Precondition.checkArgument(@query.resource.indexOf('urn:') == 0, true,
      "invalid query.resource value; expected URN, got: #{@query.resource}")
    Precondition.checkArgument(@query.resource.indexOf('collection=') > 0, true,
      "invalid query.resource value; expected collection URN, got: #{@query.resource}")

    opts = @query.opts or {}

    {@backoffAfterNTimeouts, @stream, @pauseNMsBetweenRequests, @bumpAfterNTimeouts} = opts
    @backoffAfterNTimeouts ?= 10
    @pauseNMsBetweenRequests ?= 50
    @bumpAfterNTimeouts = 5
    @stream ?= true

    @_running = false
    @_timeouts = 0
    @_errors = 0
    @_closed = false
    @_pause = @pauseNMsBetweenRequests
    @_parked = undefined
    @buffer = []

    @on 'error', (args...) ->

  hasNext: ->
    return true

  count: ->
    return @buffer.length

  read: (opts={}) ->
    {size} = opts
    size ?= Infinity
    Precondition.checkArgumentType(size, 'number')
    return @buffer.splice(0, size)

  close: ->
    @_closed = true

  isLive: ->
    return @stream

  isCatchingUp: (margin=5000) ->
    if @_timeouts > 0 then return false
    return @query.gt > ((new Date().getTime() - margin) * 1000)

  isParked: ->
    return @_parked

  fault: ->
    @next()

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
        @backoff 4
        @emit 'error', err
      finally
        if @stream and not @_closed
          console.log("Streaming in #{this._pause}ms")
          setTimeout(@next.bind(this), @_pause)

  ###*
  # Progressively backoff to a maximum delay interval.
  ###
  _backoff: (coeff) ->
    @_pause = Math.min(@_pause * coeff, 90 * 1000)
    @emit 'backoff', @_pause

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


class AwaitQuery
  constructor: (@resource) ->
    Precondition.checkArgumentType(@resource, 'string', "invalid resource value: #{@resource}")

  buildPathAndQuery: ->
    return ["/await/", {resource: @resource}]


class CollectionUpdatesQuery
  constructor: (@resource, eventId, @opts={}) ->
    Precondition.checkArgumentType(@resource, 'string', "invalid resource value: #{@resource}")
    Precondition.checkArgument(@resource.indexOf('urn:') == 0, true,
      "invalid query.resource value; expected URN, got: #{@resource}")
    Precondition.checkArgument(@resource.indexOf('collection=') > 0, true,
      "invalid query.resource value; expected collection URN, got: #{@resource}")

    {@version, @timeout, @bumpAfterNTimeouts} = @opts
    @opts.stream ?= true

    @collectionId = decodeURIComponent(@resource.split(/collection=/)[1])
    @_seen = []
    @gt = eventId
    @version ?= "3.1"
    @bumpAfterNTimeouts ?= 5

  buildPathAndQuery: ->
    return ["/v#{@version}/collection/#{@collectionId}/#{@gt}/", {}]

  update: (data) ->
    Precondition.checkArgument(data.maxEventId?, true, "fetched data has no .maxEventId!")
    eventId = data.maxEventId
    if @_seen.indexOf(eventId) != -1
      @_seen.push(eventId)
      @_seen.sort()
      @gt = Math.max(@_seen[@_seen.length - 1], @gt) + 1
      #@gt = @_seen[@_seen.length - 1] + 1
      return

    if @_seen.push(eventId) > 100
      @_seen.shift()

    @gt = eventId
    return data

  onTimeout: (data, count) ->
    if count % @bumpAfterNTimeouts == 0
      @gt++


module.exports =
  PerseidsCursor: PerseidsCursor
  CollectionUpdatesQuery: CollectionUpdatesQuery
