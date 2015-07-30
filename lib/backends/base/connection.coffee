request = require 'superagent'
{EventEmitter} = require 'events'
{Precondition} = require '../../errors.coffee'


class BaseConnection extends EventEmitter
  constructor: ->
    @on 'error', ->

  auth: (@token) ->
    if @token?
      Precondition.equal(typeof @token, 'string', "token is not a string.")

  _emit: EventEmitter::emit

  emit: (args...) ->
    @_emit.apply(this, args)
    args.unshift('*')
    @_emit.apply(this, args)

  close: () ->


module.exports =
  BaseConnection: BaseConnection
