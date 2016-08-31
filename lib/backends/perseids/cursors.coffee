{EventEmitter} = require '../../events.coffee'
{PressureRegulator} = require '../flow.coffee'
{OriginRouter} = require '../routing.coffee'
{Precondition, ValueError, Meter} = require '../../errors.coffee'
{Promise} = require 'es6-promise'

###*
  A cursor for paging through Perseids data.

  @event PerseidsCursor#error
  @event PerseidsCursor#readable
  @event PerseidsCursor#timeout
  @event PerseidsCursor#closed

  Errors (cursor)
  Backoff (cursor)
  Load balancing strategy (query)
  Pauses (query)

###
class PerseidsCursor extends EventEmitter
  constructor: (@connection, @query, opts={}) ->
    @meter = new Meter
    # is the cursor closed
    @_closed = false
    @_request = null
    {@buffer, @regulator} = opts
    @buffer ?= null
    @regulator ?= new PressureRegulator()

    @on 'error', =>
      @meter.inc 'seqErrors', 'errors'
      @meter.reset 'seqTimeouts', 'timeouts'

    @on 'fetchError', (err) =>
      @meter.inc 'fetchErrors'
      @regulator.hardBackoff()
      @emit 'backoff'
      @emit 'error', err

    @on 'timeout', =>
      @meter.reset 'seqErrors', 'errors'
      @meter.inc 'seqTimeouts', 'timeouts'

    @on 'duplicate', =>
      @meter.reset 'seqTimeouts', 'timeouts'
      @meter.reset 'seqErrors', 'errors'
      @meter.inc 'duplicates'

    @on 'backoff', =>
      @meter.val 'backoff', @regulator.current()

    @on 'wakeup', =>
      @meter.inc 'wakeup'
      @meter.val 'backoff', @regulator.current()


    @on 'received', (res) =>
      @meter.reset 'seqTimeouts', 'timeouts'
      @meter.reset 'seqErrors', 'errors'
      @meter.inc 'count'

      if @buffer?
        @buffer.push(res.value)

        @emit 'readable', {
          buffered: @buffer.length
          data: res.value
          isDone: res.close
        }

  ###*
  # Can more be read from the cursor?
  ###
  hasNext: ->
    Precondition.checkArgumentType(@query.hasNext, 'function', "query does not implement hasNext")
    return @query.hasNext()

  ###*
  # Read any buffered items.
  ###
  read: (opts={}) ->
    Precondition.equal(@buffer?, true, "buffer not initialized, cannot read.")
    {size} = opts
    size ?= Infinity
    Precondition.checkArgumentType(size, 'number')
    return @buffer.splice(0, size)

  ###*
  # Close the cursor. After, it is no longer usable.
  ###
  close: ->
    if @_closed is true
      return
    @_closed = true
    @emit 'closed'
    @cancel()

  ###*
  # Is this cursor still usable?
  ###
  isLive: ->
    return @_closed is false and @hasNext() is true

  collectRoutingParams: (obj) ->
    @query.collectRoutingParams(obj)

  ###*
  # Mechanism to sleep.
  ###
  sleep: (defaultMs=30*1000) ->
    Precondition.checkArgumentType(defaultMs, 'number')
    @regulator.slowBackoff(defaultMs)
    @emit 'backoff'
    @interrupt()

  ###*
  # Provides a mechanism for waking up from sleep.
  ###
  wakeUp: ->
    @regulator.reset()
    @interrupt()
    @emit 'wakeup'

  ###*
  # Provide a promise interface to the next batch of data in the stream
  ###
  next: ->
    @_request ?= @_next()
    return @_request

  ###*
  # Cancel an outstanding backend request. This will render the cursor unusable.
  ###
  cancel: (fn) ->
    if fn?
      @_cancel = fn
      return
    else if @_cancel?
      @_cancel()
      @_cancel = null
    @close()

  ###*
  # Interrupt any client-initiated pause. This will not cancel or invalidate
  # the cursor or outstanding futures.
  ###
  interrupt: (fn) ->
    if fn?
      @_interrupt = fn
    else if @_interrupt?
      @_interrupt()
      @_interrupt = null

  _next: ->
    if @_closed
      return Promise.reject(new ValueError('cursor closed'))

    return @query.next(this, @connection).then (res) =>
      try
        if @_closed
          throw new ValueError('cursor closed')
        return res.value
      finally
        @_request = null
        if res? and res.close
          @close()

  _pause: ->
    return @regulator.pause(cursor: this)


###*
# Notice cycles in visited objects.
###
class CycleDetector
  constructor: (@size=100) ->
    @_seen = []

  visited: (value) ->
    if @_seen.indexOf(value) != -1
      return true

    if @_seen.push(value) > @size
      @_seen.shift()
    return false

  max: ->
    @_seen.sort()
    return @_seen[@_seen.length - 1]


###*
# Uses the Await functionality which provides distributed change notification.
###
class AwaitQuery
  PATH: "/await/"
  
  constructor: (@resource, opts={}) ->
    Precondition.checkArgumentType(@resource, 'string', "invalid resource value: #{@resource}")
    @completed = null
    {@router} = opts
    @router ?= new OriginRouter

  hasNext: ->
    return not @completed

  collectRoutingParams: (obj) ->
    obj.resource = @resource
    obj.method = 'await'
    obj.salt = '' + Math.random()

  next: (cursor, connection) ->
    Precondition.checkArgumentType(connection?.fetch, 'function')
    Precondition.checkArgumentType(cursor?.emit, 'function')
    if @completed
      return Promise.resolve(@completed)
    return cursor._pause().then () =>
      return @router.route(cursor, connection)
    .then (server) =>
      Precondition.checkArgumentType(server.url, 'string')
      return connection.fetch("#{server.url}#{@PATH}", {resource: @resource} )
    .catch (err) =>
      cursor.emit 'fetchError', err
      throw err
    .then (result) =>
      if result.data.active
        @completed = result.data
        val = {
          value: result.data
          close: true
        }
        cursor.emit 'received', val
        return val
      if result.data.timeout
        cursor.emit 'timeout', result.data
        # A timeout means we're getting data
        # which means we're live.
        cursor.wakeUp()
        return next(cursor, connection)
      cursor.emit 'unknown', result
      throw new ValueError(result)


###*
# Follow a stream of collection updates.
###
class CollectionUpdatesQuery
  constructor: (resource, @eventId, opts) ->
    Precondition.checkArgumentType(resource, 'string',
      "invalid resource value: #{resource}")
    Precondition.checkArgumentType(@eventId, 'number', "invalid eventId: #{eventId}")
    if resource.indexOf("urn:") == 0
      Precondition.checkArgument(resource.indexOf('collection=') > 0, true,
        "invalid query.resource value; expected collection URN, got: #{resource}")
      @collectionId = decodeURIComponent(resource.split(/collection=/)[1])
    @collectionId ?= resource

    {@version, @nudgeAfterNTimeouts, @backoffAfterNTimeouts} = opts
    {@router, @backoff} = opts
    @router ?= new ClientsideRouter(new ConsistentHasher().selector)
    @backoff ?= new PressureRegulator()
    @version ?= "3.1"
    @backoffAfterNTimeouts ?= 10
    @nudgeAfterNTimeouts ?= 5
    @cycleDetector = new CycleDetector()
    @_parked = undefined
    @lastDelta = null

  collectRoutingParams: (obj) ->
    obj.collectionId = @collectionId
    obj.method = 'await'
    obj.salt = '' + Math.random()

  isCatchingUp: (margin=5000) ->
    if @lastDelta is null then return true
    return @query.gt > ((new Date().getTime() - margin) * 1000)

  isParked: ->
    return @_parked == true

  hasNext: -> true

  next: (cursor, connection) ->
    Precondition.checkArgumentType(connection?.getServerAdjustedTime, 'function')
    Precondition.checkArgumentType(cursor?.meter)
    return @_fetch(cursor, connection).then (res) =>
      Precondition.checkArgument(res.data?, true, "fetched data has no .data!")
      if res.data.timeout
        @lastDelta = @connection.getServerAdjustedTime().getTime()
        @_parked = res.data.parked
        cursor.emit 'timeout', res.data
        if @cursor.meter.timeouts % @nudgeAfterNTimeouts == 0
          @eventId++
          cursor.emit 'nudge', @eventId
        if @cursor.meter.timeouts > @backoffAfterNTimeouts == 0
          @backoff.slowBackoff(1)
          cursor.emit 'backoff', @backoff.current()
        return @next(cursor, connection)

      @_parked = false
      @backoff.reset()
      cursor.emit 'backoff', @backoff.current()

      Precondition.checkArgument(res.data.maxEventId?, true, "fetched data has no .maxEventId!")
      if @cycleDetector.visited(res.data.maxEventId)
        @eventId = @cycleDetector.max() + 1
        cursor.emit 'duplicate', res.data.maxEventId
        return @next(cursor, connection)
      @lastDelta = @connection.getServerAdjustedTime().getTime() - (res.data.maxEventId / 1000)
      val = {
        value: res.data
        close: false
      }
      cursor.emit 'received', val
      return true
    .catch (err) =>
      cursor.emit 'error', err
      @backoff.hardBackoff()
      cursor.emit 'backoff', @backoff.current()
      throw err

  path: ->
    return "/v#{@version}/collection/#{@collectionId}/#{@eventId}/"

  _fetch: (cursor, connection) ->
    return @backoff.pause().then () =>
      return @router.route(cursor, connection)
    .then (baseUrl) =>
      return connection.fetch "#{baseUrl}#{@path()}", {}


module.exports =
  PerseidsCursor: PerseidsCursor
  CollectionUpdatesQuery: CollectionUpdatesQuery
  AwaitQuery: AwaitQuery
  _private:
    CycleDetector: CycleDetector

