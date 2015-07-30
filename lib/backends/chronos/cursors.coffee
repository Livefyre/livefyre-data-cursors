{EventEmitter} = require 'events'
{Precondition, DataError, Logger} = require '../../errors.coffee'

module.exports = exports = {}


class ChronosCursor extends EventEmitter
  constructor: (@client, @query, opts={}) ->
    {@cursor} = opts
    @cursor ?= null
    @buffer = []
    Precondition.checkArgumentType(@query, 'object', "invalid query value: #{@query}")
    Precondition.checkArgumentType(@query.resource, 'string', "invalid query.resource value: #{@query.resource}")
    Precondition.checkArgument(@query.resource.indexOf('urn:') == 0, true,
      "invalid query.resource value; expected URN, got query: #{@query.resource.indexOf('urn:')}")

    @normalizeQuery @query

    @on 'error', (args...) ->
      #Logger.error("ChronosCursor", args...)

  hasNext: ->
    if not @cursor?
      return undefined
    return @cursor.hasNext

  count: ->
    return @buffer.length

  read: (opts={}) ->
    {size, fault} = opts
    size ?= Infinity
    fault ?= false
    Precondition.checkArgumentType(size, 'number')
    Precondition.checkArgumentType(fault, 'boolean')

    b = @buffer.splice(0, size)
    if b.length
      console.log("read buffered #{b.length}, remaining: #{@buffer.length}")
      return b

    # no more data to be had.
    if @hasNext() is false
      console.log("no more data")
      return null

    if fault
      @fault()
    return undefined

  fault: ->
    @emit 'pagefault'
    @next()

  isLive: ->
    return false

  next: ->
    console.log("fetching", @query)
    @client.fetch @query, @_processResponse.bind(this)

  _processResponse: (result) ->
    try
      if result.err?
        throw result.err
      data = result.data
      Precondition.checkArgument(data?, true, "fetched data has no .data!")
      Precondition.checkArgument(data.meta?, true, "fetched data has no .meta!")
      @cursor = data.meta.cursor
      console.log(">", @cursor)
      Precondition.checkArgumentType(@cursor, 'object')
      Precondition.checkArgumentType(data.data, 'array')
      @buffer.push(data.data...)
      added = data.data
    catch err
      @emit 'error', err
      return

    if @query.gt or @query.gte
      @query.gte = @cursor.next
      delete @query.gt
    if @query.lt or @query.lte
      @query.lte = @cursor.next
      delete @query.lt

    @emit 'readable', {
      buffered: @buffer.length
      data: added
      isDone: not @hasNext()
      next: @cursor.next
    }
    @emit 'end' if not @hasNext()


  normalizeQuery: ->
    query = @query
    if not query.limit?
      query.limit = 10
    if query.since?
      query.order = 'asc'
      query.gt = query.since
      delete query.since
    if query.until?
      query.order = 'desc'
      query.gt = query.until
      delete query.until
    if not query.order?
      query.order = 'desc'
    if not query.lt? and not query.lte?
      query.lte = new Date().toISOString()


exports.ChronosCursor = ChronosCursor


exports.RecentQuery = (urn, limit=10, cursorOpts={}) ->
  Precondition.checkArgumentType(urn, 'string', 'urn must be a string')
  return {
    resource: urn
    lte: new Date().toISOString()
    order: 'desc'
    limit: limit
    opts: cursorOpts
  }

exports.UnreadQuery = (urn, lastRead, limit=10, cursorOpts={}) ->
  Precondition.checkArgumentType(urn, 'string', 'urn must be a string')
  Precondition.checkArgumentType(lastRead, 'string', 'lastRead must be a string')
  return {
    resource: urn
    lte: new Date().toISOString()
    gt: lastRead
    order: 'desc'
    limit: limit
    opts: cursorOpts
  }

exports.ReadQuery = (urn, lastRead, limit=10, cursorOpts={}) ->
  Precondition.checkArgumentType(urn, 'string', 'urn must be a string')
  Precondition.checkArgumentType(lastRead, 'string', 'lastRead must be a string')
  return {
    resource: urn
    gte: lastRead
    order: 'desc'
    limit: limit
    opts: cursorOpts
  }

