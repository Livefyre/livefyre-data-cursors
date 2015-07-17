assert = require 'assert'

class ChronosCursor
  constructor: (@client, opts={}) ->
    {@urn, @start, @order, @limit, @cursor} = opts
    assert.ok @urn, "invalid instantiation without valid opts.urn value"
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
      callback null, []
      return

    @client.fetch @_query(), (args...) ->
      @_onResponse(args..., callback)

  _onResponse: (err, res, data, callback) ->
    if err?
      return callback err

    if not data.meta? or not data.meta.cursor?
      return callback new InvalidDataError("invalid .meta field", data)

    @cursor = data.meta.cursor
    callback err, {data: data.data, cursor: data.meta.cursor}

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


class InvalidDataError extends Error
  constructor: (@message, @data) ->
    @name = "InvalidDataError"


module.exports =
  ChronosCursor: ChronosCursor