{ChronosConnection} = require './chronos/connection.coffee'
{PerseidsConnection} = require './perseids/connection.coffee'
{LivecountConnection} = require './livecount/connection.coffee'
# we can't import this until we fix the stream client issue.
#{StreamConnection} = require './stream/connection.coffee'
{Precondition} = require '../errors.coffee'


class ConnectionFactory
  constructor: (@env, opts={}) ->
    #Precondition.checkArgumentType(@cluster, 'string')
    #Precondition.checkArgument(@cluster.endsWith 'fyre.co', false, "cluster is not network name")
    {@token, @onError, @network} = opts

  chronos: ->
    return @_setup "Chronos", ChronosConnection

  personalStream: ->
    return @_setup "Stream", StreamConnection

  perseids: ->
    return @_setup "Perseids", PerseidsConnection

  livecount: ->
    return @_setup "Livecount", LivecountConnection

  _setup: (name, cls) ->
    c = new cls(@env)
    if @token? and c.auth?
      c.auth @token
    if @onError? and c.on?
      onerr = @onError.bind(name, c)
      c.on 'error', onerr
    return c



module.exports = (env, opts) ->
  return new ConnectionFactory(env, opts)
