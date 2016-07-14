{BaseConnection} = require '../base/connection.coffee'
{Precondition} = require '../../errors.coffee'
{PerseidsCursor} = require './cursors.coffee'
{Promise} = require 'es6-promise'
request = require 'superagent-es6-promise'


class PerseidsConnection extends BaseConnection
  ENVIRONMENTS:
    'fy.re': 'https://stream1.fy.re'
    'fyre': 'https://stream1.fyre'
    'qa': 'https://stream1.qa-ext.livefyre.com'
    'uat': 'https://stream1.t402.livefyre.com'
    'production': 'https://stream1.livefyre.com'

  constructor: (opts={environment: 'production'}) ->
    if typeof opts == 'string'
      opts = environment: opts
    if opts.environment
      Precondition.checkArgument(@ENVIRONMENTS[opts.environment]?,
        "#{@environment} is not a valid value")
      @baseUrl = @ENVIRONMENTS[opts.environment]
    else if opts.host
      @baseUrl = opts.host
    else
      Precondition.checkArgument(false, "No host/environment information provided.")
    @token = null
    @serverTime = null

    # because we don't want everything to fail on an error
    # if nobody is listening.
    @on 'error', ->

    @_cachedServers = null
    @_timeOffset = 0

  openCursor: (query) ->
    Precondition.checkArgumentType(query, 'object', "invalid query object: #{query}")
    return new PerseidsCursor(this, query)

  closeCursor: (c) ->
    c.close()

  getServers: (params) ->
    if params?
      return @_fetchServers(params)
    @_cachedServers ?= @_fetchServers()
    return Promise.resolve(@_cachedServers)

  getServerAdjustedTime: ->
    return new Date(new Date().getTime() - @_timeOffset)

  fetch: (url, params={}) ->
    Precondition.equal(typeof path, 'string')
    Precondition.equal(typeof params, 'object')
    if url.indexOf('http') != 0
      url = "#{@baseUrl}#{url}"
    req = request.get(url)
      .set('Accept', 'application/json')
      .set('Connection', 'keep-alive')
      .query(params)
    if @token
      req = req.set('Authorization', "Bearer lftoken #{@token}")
    @emit 'fetching', {
      url: url
      params: params
      withAuthorization: @token?
    }
    p = req.promise().then (res) =>
      @emit 'fetched', url, res.body
      return {
        url: url
        response: res
        data: res.body
      }
    .catch (err) =>
      @emit 'error', url, err
      throw err
    return p

  _fetchServers: (params) ->
    url = "#{@baseUrl}/servers/"
    req = request.get(url)
      .set('Accept', 'application/json')
      .set('Connection', 'close')
    if params?
      req = req.query(params)
    if @token
      req = req.set('Authorization', "Bearer lftoken #{@token}")
    p = req.promise()
      .then (res) =>
        @emit 'loadServers', res.body
        Precondition.checkArgumentType(res.body.servers, 'array')
        @_timeOffset = new Date().getTime() - (res.body.stime * 1000)
        servers = ("https://#{s.replace(/:80$/, '')}" for s in res.body.servers)
        @emit 'loadedServers', {
          url: url
          servers: servers
          timeOffset: @_timeOffset
        }
        return servers
      .catch (err) =>
        @emit 'error', "Error requesting servers #{url}", err
        return [@baseUrl]
    return p


module.exports =
  PerseidsConnection: PerseidsConnection
