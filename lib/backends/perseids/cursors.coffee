{EventEmitter} = require 'events'
{Precondition, ValueError} = require '../../errors.coffee'
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
    @timeouts = 0
    @errors = 0
    # number of sequential timeouts observed.
    @seqTimeouts = 0
    # number of sequential errors observed.
    @seqErrors = 0
    # is the cursor closed
    @_closed = false
    @_request = null
    # how many we're read total
    @_count = 0
    @lastData = null

    @on 'error', (args...) =>
      @seqErrors++
      @seqTimeouts = 0
      @errors++

    @on 'timeout', (args...) =>
      @seqErrors = 0
      @seqTimeouts++
      @timeouts++

    @on 'received', (res) =>
      @_count++
      @lastData = new Date()
      if @buffer?
        @buffer.push(res.value)

        @emit 'readable', {
          buffered: @buffer.length
          data: res.value
          isDone: res.close
        }
      #if res.close
      #  @close()
    @seqTimeouts = 0
    @seqErrors = 0

  _emit: EventEmitter::emit

  emit: (args...) ->
    @_emit.apply(this, args)
    args.unshift('*')
    @_emit.apply(this, args)

  ###*
  # Can more be read from the cursor?
  ###
  hasNext: ->
    return query.hasNext()

  ###*
  # How many items we're read in total.
  ###
  count: (add) ->
    if add?
      @_count = @_count + 1
    return @_count

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


class ProgressiveBackoff
  HARD_BACKOFF: 2000
  BASE: 2

  ## TODO: cursor movement detection

  constructor: (@defaultPause=50, @jitter=0.25, @maxPause=90 * 1000) ->
    @reset()

  reset: () ->
    @_pause = @defaultPause
    @_coeff = 1

  hardBackoff: () ->
    if @_pause < 1000
      @_pause = @HARD_BACKOFF
      return
    @_coeff++
    newmax = @HARD_BACKOFF * Math.pow(@BASE, @_coeff)
    jitter = Math.random() * (@jitter * 2) - @jitter
    @_pause = Math.min(newmax + jitter, @maxPause)

  slowBackoff: (amount) ->
    @_pause = Math.min(@_pause + amount, @maxPause)

  pause: (args...) ->
    p = @_pause
    return new Promise (resolve, reject) ->
      setTimeout () ->
        resolve(args...)
      , @_pause


class BasicRoutingStrategy
  route: (cursor, connection) ->
    return Promise.resolve(connection.baseUrl)


###*
# Direct to server router. Handles failures and re-routing.
###
class DSRRoutingStrategy

  RANDOM_SELECTOR: (list) ->
    return Math.floor(Math.random() * list.length)

  constructor: (@selector=null, @moveAfterNErrors=5) ->
    Precondition.checkArgumentType(@selector, 'function')
    @_servers = null
    @_server = null
    @move = false

  route: (cursor, connection) ->
    # move if we're havin problems
    move = @move or (cursor.seqErrors > 0 and cursor.seqErrors % @moveAfterNErrors == 0)
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
      # identify
      idx = @selector(list)
      @_server = list.splice(idx, 1)[0]
      return @_server

    return @_server


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
    if @completed
      return Promise.resolve(@completed)
    return @backoff.pause().then () =>
      return @router.route(cursor, connection)
    .then (baseUrl) =>
      return connection.fetch("#{baseUrl}#{@PATH}", {resource: @resource} )
    .catch (err) =>
      cursor.emit 'error', err
      @backoff.hardBackoff()
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
        return next(cursor, connection)
      cursor.emit 'unknown', result
      throw new ValueError(result)


###*
# Follow a stream of collection updates.
###
class CollectionUpdatesQuery
  constructor: (resource, @eventId, opts) ->
    Precondition.checkArgumentType(resource, 'string', "invalid resource value: #{resource}")
    Precondition.checkArgumentType(@eventId, 'number', "invalid eventId: #{eventId}")
    if resource.indexOf("urn:") == 0
      Precondition.checkArgument(resource.indexOf('collection=') > 0, true,
        "invalid query.resource value; expected collection URN, got: #{resource}")
      @collectionId = decodeURIComponent(resource.split(/collection=/)[1])
    @collectionId ?= resource

    {@version, @nudgeAfterNTimeouts, @backoffAfterNTimeouts} = opts
    {@router, @backoff} = opts
    @router ?= new DSRRoutingStrategy(@serverSelector)
    @backoff ?= new ProgressiveBackoff()
    @version ?= "3.1"
    @backoffAfterNTimeouts ?= 10
    @nudgeAfterNTimeouts ?= 5
    @_seen = []
    @_parked = undefined
    @_timeouts = 0
    @_duplicates = 0
    @lastDelta = null

  isCatchingUp: (margin=5000) ->
    if @_timeouts > 0 then return false
    return @query.gt > ((new Date().getTime() - margin) * 1000)

  isParked: ->
    return @_parked == true

  next: (cursor, connection) ->
    return @_fetch(cursor, connection).then (res) =>
      Precondition.checkArgument(res.data?, true, "fetched data has no .data!")
      if res.data.timeout
        @_parked = res.data.parked
        @_timeouts++
        cursor.emit 'timeout', res.data
        if @_timeouts % @nudgeAfterNTimeouts == 0
          @eventId++
          cursor.emit 'nudge', @eventId
        if @_timeouts > @backoffAfterNTimeouts == 0
          cursor.emit 'backoff', @_timeouts
          @backoff.slowBackoff(1)
        return @next(cursor, connection)

      @_timeouts = 0
      @_parked = false
      @backoff.reset()

      Precondition.checkArgument(res.data.maxEventId?, true, "fetched data has no .maxEventId!")
      if @_detectCycle(res.data)
        @_seen.sort()
        @eventId = @_seen[@_seen.length - 1] + 1
        @_duplicates++
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
      throw err

  serverSelector: (list) ->
    # TODO: implement consistent hashing.

  _fetch: (cursor, connection) ->
    return @backoff.pause().then () =>
      return @router.route(cursor, connection)
    .then (baseUrl) =>
      return connection.fetch "#{baseUrl}/v#{@version}/collection/#{@collectionId}/#{@eventId}/", {}

  _detectCycle: (id) ->
    if @_seen.indexOf(id) != -1
      return true

    if @_seen.push(id) > 100
      @_seen.shift()
    return false


module.exports =
  PerseidsCursor: PerseidsCursor
  CollectionUpdatesQuery: CollectionUpdatesQuery
  AwaitQuery: AwaitQuery
  ProgressiveBackoff: ProgressiveBackoff
  BasicRoutingStrategy: BasicRoutingStrategy
  DSRRoutingStrategy: DSRRoutingStrategy

