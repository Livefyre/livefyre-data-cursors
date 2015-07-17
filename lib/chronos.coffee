request = require 'superagent'
{EventEmitter} = require 'events'


class ChronosClient extends EventEmitter
  ENVIRONMENTS:
    'fyre': 'bootstrap.fyre'
    'qa': 'bootstrap.qa-ext.livefyre.com'
    'uat': 'bootstrap.t402.livefyre.com'
    'production': 'bootstrap.livefyre.com'

  constructor: (environment='production') ->
    @baseUrl = "https://#{@ENVIRONMENTS[environment]}/api/v4/timeline/"
    @token = null
    @on 'error', ->

  auth: (@token) ->

  _emit: EventEmitter::emit

  emit: (args...) ->
    @_emit.apply(this, args)
    args.unshift('*')
    @_emit.apply(this, args)

  cursor: (urn, opts={}) ->
    return new ChronosCursor(this, urn, opts)

  fetch: (opts, callback) =>
    req = request.get(@baseUrl)
      .set('Accept', 'application/json')
      .query(opts)

    if @token?
      req = req.set('Authorization', "lftoken #{@token}")

    req.end (err, res) =>
      if err?
        @emit 'error', "Error fetching #{opts.resource}. Error: #{err}"
        return callback err, res
      return callback err, res, res.body

  close: () ->


class ChronosCursor
  constructor: (@client, @urn, opts={}) ->
    {@start, @order, @limit, @cursor} = opts
    @start ?= null
    @order ?= -1
    @limit ?= 20
    @cursor ?= null

  hasNext: () ->
    if @order is -1
      return if @cursor then @cursor.hasPrev else true
    return if @cursor then @cursor.hasNext else true

  next: (callback) ->
    if not @hasNext()
      callback null, NaN # TODO: what is the right thing here?
      return

    @client.fetch @_query(), (err, data) =>
      if err?
        return callback err, data

      if not data.meta?
        return callback new Error("meta field not found in response"), data

      @cursor = data.meta.cursor
      callback err, data.data, data.meta.cursor

  _query: () ->
    opts =
      resource: @urn
      limit: @limit
    # TODO: we don't want to do query params for lftoken, right? because xhr?
    #if @token?
    #  query.lftoken = @token
    # TODO: figure this out...
    if @order is -1
      # backward
      opts.until = if @cursor then @cursor.prev else @start
    else if @order is 1
      opts.since = if @cursor then @cursor.next else @start
    else
      throw new Error("Invalid order value: #{@order}")
    return opts


module.exports =
  ChronosClient: ChronosClient
  ChronosCursor: ChronosCursor
