StreamBackend = require 'livefyre-stream-client'
{EventEmitter} = require 'events'
{Precondition} = require '../../errors.coffee'


class StreamConnection extends EventEmitter
  _ENVIRONMENTS: ['fyre', 'qa', 'uat', 'production']
  constructor: (@environment='production') ->
    Precondition.checkArgument(@_ENVIRONMENTS.indexOf(@environment) is not -1,
      true,
      "unknown environment: #{@environment}")
    @stream = null
    @token = null
    @cursors = []

    # because we don't want everything to fail on an error
    # if nobody is listening.
    @on 'error', ->

  auth: (@token) ->
    Precondition.checkArgument(typeof @token, 'string',
      "token is not a string: #{@token}")

  isLive: ->
    # TODO make this honest
    return true

  openCursor: (opts={}) ->
    {urn} = opts
    Precondition.checkArgument(typeof urn, 'string',
      "opts.urn is not a string: #{urn}")
    c = new StreamCursor(this, @_subscribe urn, opts)
    @cursors.push(c)
    @emit 'newCursor', c
    return c

  closeCursor: (c) ->
    @cursors.remove(c)
    try
      subscription = c.subscription
      subscription.close()
    catch e
      @emit 'error', "Failed closing subscription for #{c.urn}. Error: #{e}", e

  _subscribe: (urn) ->
    subscription = @connect().subscribe(urn)
    return subscription

  connect: ->
    if @stream?
      return @stream
    @stream = new StreamBackend(environment: @environment)
    if @token?
      stream.auth @token
      @emit 'authenticated'
    return @stream

  disconnect: () ->
    for c in @cursors
      try
        c.close()
      catch e
    try
      @stream.disconnect()
    catch e

    @stream = null
    @emit 'disconnect'

  close: ->
    @disconnect()

  _emit: EventEmitter::emit

  emit: (args...) ->
    @_emit.apply(this, args)
    args.unshift('*')
    @_emit.apply(this, args)


module.exports =
  StreamConnection: StreamConnection
