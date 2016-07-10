{BaseConnection} = require '../base/connection.coffee'
{EventEmitter} = require 'events'
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

  fetch: (path, params={}) ->
    url = null
    p = @_buildUrl(path).then (url_) =>
      url = url_
      req = request.get(url)
        .set('Accept', 'application/json')
        .set('Connection', 'keep-alive')
        .query(params)
      return req.promise()
    .then (res) =>
      @emit 'fetch', url, res.body
      return {
        url: url
        response: res
        data: res.body
      }
    .catch (err) =>
      return {
        err: err
        url: url
      }
    return p

  _buildUrl: (path) ->
    return @getServers().then (list) =>
      # TODO: implement
      return "https://#{list[0]}#{path}"

  _dsrServers: ->
    url = "#{@baseUrl}/servers/"
    req = request.get(url)
      .set('Accept', 'application/json')

    p = req.promise()
      .then (res) =>
        @emit 'loadServers', res.body
        Precondition.checkArgumentType(res.body.servers, 'array')
        @_timeOffset = new Date().getTime() - (res.body.stime * 1000)
        return (s.replace(/:80$/, '') for s in res.body.servers)
      .catch (err) =>
        @emit 'error', "Error requesting servers #{url}", err
        return [@_ENVIRONMENTS[@environment]]
      .then (list) =>
        @_cachedDsrServers = list
        return list
    return p


module.exports =
  PerseidsConnection: PerseidsConnection
