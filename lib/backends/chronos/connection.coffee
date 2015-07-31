request = require 'superagent'
{ChronosCursor} = require './cursors.coffee'
{EventEmitter} = require 'events'
{Precondition} = require '../../errors.coffee'
{BaseConnection} = require '../base/connection.coffee'

###
  Service providing data access to Chronos. Beyond environment and auth,
  this is a stateless object and can be reused in any context.

  @event ChronosConnection#error - unhandled exceptions; e.g. connection failures, etc.
###
class ChronosConnection extends BaseConnection
  ENVIRONMENTS:
    'fy.re': 'https://bootstrap.fy.re'
    'fyre': 'https://bootstrap.fyre'
    'qa': 'https://bootstrap.qa-ext.livefyre.com'
    'uat': 'https://bootstrap.t402.livefyre.com'
    'production': 'https://bootstrap.livefyre.com'

  ###
    New connection.

    @param {string} environment - One of {qa|uat|production}
  ###
  constructor: (@environment='production') ->
    Precondition.checkArgument(@ENVIRONMENTS[@environment]?,
      "#{@environment} is not a valid value")
    @baseUrl = "#{@ENVIRONMENTS[@environment]}/api/v4/timeline/"
    @token = null
    # don't term on errors:
    @on 'error', ->

  ###
    Return a cursor given a query.
    @param {object} query - the query
    @param {object} [query.opts] - cursor options.
    @return {ChronosCursor}
  ###
  openCursor: (query) ->
    Precondition.checkArgumentType(query, 'object', "invalid query object: #{query}")
    opts = query.opts or {}
    delete query.opts
    return new ChronosCursor(this, query, opts)

  ###
    Returns the number of items in the result set given a query.
  ###
  count: (query) ->
    throw new Error("not implemented")

  ###
    Directy fetch from the HTTP endpoint.
  ###
  fetch: (opts, callback) =>
    Precondition.equal(typeof opts, 'object')
    Precondition.equal(typeof callback, 'function')
    req = request.get(@buildUrl opts)
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

  ###
    Construct a url from options.
  ###
  buildUrl: (opts) ->
    return @baseUrl

  ###
    Cleanup resources.
  ###
  close: ->
    @removeAllListeners 'error'


class MockChronosConnection extends ChronosConnection
  constructor: (@data_or_files)->
    super 'qa'
    Precondition.checkArgumentType(@data_or_files, 'array', "invalid query object: #{@data_or_files}")

  fetch: (opts, callback) ->
    if typeof @data_or_files[0] is 'object'
      return callback @data_or_files.shift()
    @baseUrl = @data_or_files.shift()
    Precondition.checkArgumentType(@baseUrl, 'string', "invalid baseUrl; are we out of data? #{@baseUrl}")
    super opts, callback


module.exports =
  ChronosConnection: ChronosConnection
  MockConnection: MockChronosConnection
