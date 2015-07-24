{EventEmitter} = require 'events'
{Precondition} = require './errors.coffee'


class Environment extends EventEmitter
  ENVS = [
    'fyre'
    'qa'
    'uat'
    'production'
  ]
  constructor: (@environment) ->
    Precondition.checkArgument(@ENVS[@environment]?, true,
      "invalid environment: #{@environment}; known: #{@ENVS.join(',')}")
    @token = null

  onLogin: (@token) ->
