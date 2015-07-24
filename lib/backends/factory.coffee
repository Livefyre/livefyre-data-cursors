{ChronosConnection} = require './chronos/connection.coffee'
{StreamConnection} = require './stream/connection.coffee'
{Precondition} = require '../errors.coffee'


class ConnectionFactory
  constructor: (@cluster, opts={}) ->
    Precondition.checkArgumentType(@cluster, 'string')
    Precondition.checkArgument(@cluster.endsWith 'fyre.co', false, "cluster is not network name")
    {@token, @onError, @network} = opts

  chronos: ->
    c = new ChronosConnection(@env)
    @_setup c
    return c

  personalStream: ->
    c = new StreamConnection(@env)
    @_setup c
    return c

  stream: ->

  livecount: ->

  _setup: (c) ->
    if @token? and c.auth?
      c.auth @token
    if @onError? and c.on?
      c.on 'error', @onError


module.exports = (env) ->
  return new ConnectionFactory(env)
