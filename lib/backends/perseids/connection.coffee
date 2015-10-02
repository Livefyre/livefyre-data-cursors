{BaseConnection} = require '../base/connection.coffee'
{EventEmitter} = require 'events'
{Precondition} = require '../../errors.coffee'
{PerseidsCursor} = require './cursors.coffee'
Promise = require 'promise'
request = require 'superagent'


class PerseidsConnection extends BaseConnection
  ENVIRONMENTS:
    'fy.re': 'https://stream1.fy.re'
    'fyre': 'https://stream1.fyre'
    'qa': 'https://stream1.qa-ext.livefyre.com'
    'uat': 'https://stream1.t402.livefyre.com'
    'production': 'https://stream1.livefyre.com'

  constructor: (@environment='production') ->
    Precondition.checkArgument(@ENVIRONMENTS[@environment]?,
      "#{@environment} is not a valid value")
    @baseUrl = "#{@ENVIRONMENTS[@environment]}"
    @token = null
    @serverTime = null

    # because we don't want everything to fail on an error
    # if nobody is listening.
    @on 'error', ->

    @_cachedDsrServers = @_dsrServers()
    @_timeOffset = 0

  openCursor: (query) ->
    Precondition.checkArgumentType(query, 'object', "invalid query object: #{query}")
    return new PerseidsCursor(this, query)

  closeCursor: (c) ->
    c.close()

  getServers: ->
    return Promise.resolve(@_cachedDsrServers)

  getServerAdjustedTime: ->
    return new Date(new Date().getTime() - @_timeOffset)

  fetch: (path, params, callback) ->
    # TODO determine if we should load balance this in the client.
    @getServers().then (list) =>
      url = "#{@baseUrl}#{path}"
      req = request.get(url)
        .set('Accept', 'application/json')
        .set('Connection', 'keep-alive')
        .query(params)
      console.log(url)
      req.end (err, res) =>
        if err?
          @emit 'error', "Error fetching #{path}. Error: #{err}", err
          return callback {err: err, response: res, data: undefined}
        return callback {
          err: err
          response: res
          data: res.body
        }

  _dsrServers: ->
    url = "#{@baseUrl}/servers/"
    req = request.get(url)
      .set('Accept', 'application/json')

    p = Promise.denodeify(req.end.bind(req))()
      .then (res) =>
        @emit 'loadServers', res.body
        Precondition.checkArgumentType(res.body.servers, 'array')
        @_timeOffset = new Date().getTime() - (res.body.stime * 1000)
        return res.body.servers
      .catch (err) =>
        @emit 'error', err
        return [@_ENVIRONMENTS[@environment]]
      .then (list) =>
        @_cachedDsrServers = list
        return list
    return p


module.exports =
  PerseidsConnection: PerseidsConnection
