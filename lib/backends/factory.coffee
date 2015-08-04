{ChronosConnection} = require './chronos/connection.coffee'
{PerseidsConnection} = require './perseids/connection.coffee'
# we can't import this until we fix the stream client issue.
#{StreamConnection} = require './stream/connection.coffee'
{Precondition} = require '../errors.coffee'


class ConnectionFactory
  constructor: (@env, opts={}) ->
    #Precondition.checkArgumentType(@cluster, 'string')
    #Precondition.checkArgument(@cluster.endsWith 'fyre.co', false, "cluster is not network name")
    {@token, @onError, @network} = opts

  chronos: ->
    c = new ChronosConnection(@env)
    @_setup "Chronos", c
    return c

  personalStream: ->
    c = new StreamConnection(@env)
    @_setup "Stream", c
    return c

  stream: ->

  perseids: ->
    c = new PerseidsConnection(@env)
    @_setup "Perseids", c
    return c

  livecount: ->

  _setup: (name, c) ->
    if @token? and c.auth?
      c.auth @token
    if @onError? and c.on?
      onerr = @onError.bind(name, c)
      c.on 'error', onerr



module.exports = (env, opts) ->
  return new ConnectionFactory(env, opts)
