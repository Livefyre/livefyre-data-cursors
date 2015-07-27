request = require 'superagent'
{ChronosCursor} = require './cursors.coffee'
{EventEmitter} = require 'events'
{Precondition} = require '../../errors.coffee'
{BaseConnection} = require '../base/connection.coffee'


class ChronosConnection extends BaseConnection
  ENVIRONMENTS:
    'fy.re': 'https://bootstrap.fy.re'
    'fyre': 'https://bootstrap.fyre'
    'qa': 'https://bootstrap.qa-ext.livefyre.com'
    'uat': 'https://bootstrap.t402.livefyre.com'
    'production': 'https://bootstrap.livefyre.com'

  constructor: (@environment='production') ->
    Precondition.checkArgument(@ENVIRONMENTS[@environment]?,
      "#{@environment} is not a valid value")
    @baseUrl = "#{@ENVIRONMENTS[@environment]}/api/v4/timeline/"
    @token = null
    # don't term on errors:
    @on 'error', ->


  openCursor: (query) ->
    Precondition.checkArgumentType(query, 'object', "invalid query object: #{query}")
    opts = query.opts or {}
    delete query.opts
    return new ChronosCursor(this, query, opts)

  count: (query) ->
    throw new Error("not implemented")

  fetch: (opts, callback) =>
    Precondition.equal(typeof opts, 'object')
    Precondition.equal(typeof callback, 'function')
    req = request.get(@baseUrl)
      .set('Accept', 'application/json')
      .query(opts)

    if @token?
      req = req.set('Authorization', "lftoken #{@token}")

    req.end (err, res) =>
      if err?
        @emit 'error', "Error fetching #{opts.resource}. Error: #{err}", err
        return callback {err: err, response: res, data: undefined}
      return callback {
        err: err
        response: res
        data: res.body
      }

  close: () ->


class MockChronosConnection extends EventEmitter
  constructor: (data...) ->

  auth: (@token) ->

  _emit: EventEmitter::emit

  emit: (args...) ->
    @_emit.apply(this, args)
    args.unshift('*')
    @_emit.apply(this, args)

  openCursor: (query, opts={}) ->
    Precondition.checkArgumentType(query, 'object', "invalid query object: #{query}")
    return new ChronosCursor(this, query, opts)

  fetch: (opts, callback) =>
    Precondition.equal(typeof opts, 'object')
    Precondition.equal(typeof callback, 'function')

    req.end (err, res) =>
      if err?
        @emit 'error', "Error fetching #{opts.resource}. Error: #{err}"
        return callback err, res
      return callback err, {
        response: res
        data: data
      }

  close: () ->


module.exports =
  ChronosConnection: ChronosConnection
