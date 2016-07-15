{EventEmitter} = require '../../events.coffee'
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
  constructor: (@connection, @query, @buffer=null) ->
    @meter = new Meter
    # is the cursor closed
    @_closed = false
    @_request = null
    # how many we're read total

    @on 'error', (args...) =>
      @meter.inc 'seqErrors', 'errors'
      @meter.reset 'seqTimeouts', 'timeouts'

    @on 'timeout', (args...) =>
      @meter.reset 'seqErrors', 'errors'
      @meter.inc 'seqTimeouts', 'timeouts'

    @on 'duplicate', =>
      @meter.reset 'seqTimeouts', 'timeouts'
      @meter.reset 'seqErrors', 'errors'
      @meter.inc 'duplicates'

    @on 'backoff', (value) =>
      @meter.val 'backoff', value


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
    return query.hasNext()

  ###*
  # Read any buffered items.
  ###
  read: (opts={}) ->
    Precondition.equal(@buffer?, true, "buffer not initialized, cannot read.")
    {size} = opts
    size ?= Infinity
    Precondition.checkArgumentType(size, 'number')
    return @buffer.splice(0, size)


  close: ->
    @_closed = true
    @emit 'closed'

  isLive: ->
    return @_closed == false and @hasNext() != false

  ###*
  # Provide a promise interface to the next batch of data in the stream
  ###
  next: ->
    @_request ?= @_next()
    return @_request

  cancel: (fn) ->
    if fn?
      @_cancel = fn
    else if @_cancel?
      @_cancel()


  interrupt: (fn) ->
    if fn?
      @_interrupt = fn
    else if @_interrupt?
      @_interrupt()


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

###*
#
###
class ProgressiveBackoff
  HARD_BACKOFF: 2000
  BASE: 2

  constructor: (opts={}) ->
    Precondition.checkArgumentType(opts, 'object')
    {pause, @jitter, @maxPause} = opts
    @defaultPause = if pause? then pause else 50
    @jitter ?=0.25
    @maxPause ?= 90 * 1000
    @reset()

  reset: () ->
    @_pause = @defaultPause
    @_coeff = 1

  current: ->
    return @_pause

  hardBackoff: () ->
    if @_pause < 1000
      @_pause = @HARD_BACKOFF
      return
    @_coeff++
    newmax = @HARD_BACKOFF * Math.pow(@BASE, @_coeff)
    jitter = Math.random() * (@jitter * 2) - @jitter
    @_pause = Math.min(newmax + jitter, @maxPause)

  slowBackoff: (amount) ->
    Precondition.checkArgumentType(amount, 'number')
    @_pause = Math.min(@_pause + amount, @maxPause)

  pause: (opts={}, args...) ->
    {cursor, interrupter, canceller, duration} = opts
    Precondition.checkOptionType(cursor?.cancel, 'function')
    Precondition.checkOptionType(cursor?.interrupt, 'function')
    Precondition.checkOptionType(interrupter, 'function')
    Precondition.checkOptionType(canceller, 'function')
    Precondition.checkOptionType(duration, 'number')
    p = duration or @_pause
    return new Promise (resolve, reject) ->
      run = false
      cancelled = false
      fn = () ->
        if run
          return
        run = true
        try
          if cancelled
            throw new Error('cancelled')
          resolve(args...)
        catch e
          reject e

      if canceller?
        canceller (strict=false) ->
          if strict
            if cancelled
              Precondition.illegalState 'already cancelled'
            if run
              Precondition.illegalState 'already run'
          cancelled = true
      if interrupter?
        interrupter fn
      setTimeout fn, @_pause


###*
# Skips routing, uses the base URL
###
class BasicRoutingStrategy
  route: (cursor, connection) ->
    Precondition.checkArgumentType(connection.baseUrl, 'string')
    return Promise.resolve(connection.baseUrl)


###*
# Direct to server router. Handles failures and re-routing.
###
class DSRRoutingStrategy

  ###*
  # Select a random server.
  ###
  RANDOM_SELECTOR: (list) ->
    return Math.floor(Math.random() * list.length)

  constructor: (@selector=null, @moveAfterNErrors=5) ->
    Precondition.checkArgumentType(@selector, 'function')
    Precondition.checkArgumentType(@moveAfterNErrors, 'number')
    @_servers = null
    @_server = null
    @move = false

  route: (cursor, connection) ->
    # move if we're havin problems
    Precondition.checkArgumentType(cursor.meter, 'object')
    Precondition.checkArgumentType(connection.getServers, 'function')
    move = @move or (cursor.meter.seqErrors > 0 and cursor.meter.seqErrors % @moveAfterNErrors == 0)
    if move
      @_server = null
      @move = false
    else if @_server? # we can use the precomputed value.
      return Promise.resolve(@_server)

    # get a list of servers if we don't have any.
    if not @_servers? or @_servers.length == 0
      refresh = @_servers and @_servers.length == 0
      @_servers = connection.getServers(refresh).then (list) =>
        # copy and return a mutable value
        val = [].concat(list)
        @_servers = val
        return val

    @_server = Promise.resolve(@_servers).then (list) =>
      # TODO: solve for 'last man standing' problem
      # identify
      idx = @selector(list)
      @_server = list.splice(idx, 1)[0]
      return @_server

    return @_server


class ConsistentHasher
  constructor: (@query) ->
    @salt = null

  select: (list) ->
    raise new Error('not implemented')

  selector: ->
    return (list) =>
      return @select(list)


###*
# Uses the Await functionality which provides distributed change notification.
###
class AwaitQuery
  PATH: "/await/"
  
  constructor: (@resource, opts={}) ->
    Precondition.checkArgumentType(@resource, 'string', "invalid resource value: #{@resource}")
    @completed = null
    {@router, @backoff} = opts
    @router ?= new BasicRoutingStrategy()
    @backoff ?= new ProgressiveBackoff()

  next: (cursor, connection) ->
    Precondition.checkArgumentType(connection?.fetch, 'function')
    Precondition.checkArgumentType(cursor?.emit, 'function')
    if @completed
      return Promise.resolve(@completed)
    return @backoff.pause(cursor: cursor).then () =>
      return @router.route(cursor, connection)
    .then (baseUrl) =>
      return connection.fetch("#{baseUrl}#{@PATH}", {resource: @resource} )
    .catch (err) =>
      cursor.emit 'error', err
      @backoff.hardBackoff()
      cursor.emit 'backoff', @backoff.current()
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
        @backoff.reset()
        cursor.emit 'backoff', @backoff.current()
        return next(cursor, connection)
      cursor.emit 'unknown', result
      throw new ValueError(result)


###*
# Notice cycles in visited objects.
###
class CycleDetector
  constructor: (@size=100) ->
    @_seen = []

  notice: (value) ->
    if @_seen.indexOf(value) != -1
      return true

    if @_seen.push(value) > @size
      @_seen.shift()
    return false

  max: ->
    @_seen.sort()
    return @_seen[@_seen.length - 1]


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
    @router ?= new DSRRoutingStrategy(new ConsistentHasher().selector)
    @backoff ?= new ProgressiveBackoff()
    @version ?= "3.1"
    @backoffAfterNTimeouts ?= 10
    @nudgeAfterNTimeouts ?= 5
    @cycleDetector = new CycleDetector()
    @_parked = undefined
    @lastDelta = null

  isCatchingUp: (margin=5000) ->
    if @lastDelta is null then return true
    return @query.gt > ((new Date().getTime() - margin) * 1000)

  isParked: ->
    return @_parked == true

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
      if @cycleDetector.seen(res.data.maxEventId)
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

  _fetch: (cursor, connection) ->
    return @backoff.pause().then () =>
      return @router.route(cursor, connection)
    .then (baseUrl) =>
      return connection.fetch "#{baseUrl}/v#{@version}/collection/#{@collectionId}/#{@eventId}/", {}



module.exports =
  PerseidsCursor: PerseidsCursor
  CollectionUpdatesQuery: CollectionUpdatesQuery
  AwaitQuery: AwaitQuery
  ProgressiveBackoff: ProgressiveBackoff
  BasicRoutingStrategy: BasicRoutingStrategy
  DSRRoutingStrategy: DSRRoutingStrategy

