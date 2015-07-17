request = require 'superagent'
{ChronosCursor} = require './cursors.coffee'
{EventEmitter} = require 'events'


class ChronosConnection extends EventEmitter
  ENVIRONMENTS:
    'fyre': 'bootstrap.fyre'
    'qa': 'bootstrap.qa-ext.livefyre.com'
    'uat': 'bootstrap.t402.livefyre.com'
    'production': 'bootstrap.livefyre.com'

  constructor: (environment='production') ->
    @baseUrl = "https://#{@ENVIRONMENTS[environment]}/api/v4/timeline/"
    @token = null
    @on 'error', ->

  auth: (@token) ->

  _emit: EventEmitter::emit

  emit: (args...) ->
    @_emit.apply(this, args)
    args.unshift('*')
    @_emit.apply(this, args)

  openCursor: (opts={}) ->
    return new ChronosCursor(this, opts)

  fetch: (opts, callback) =>
    req = request.get(@baseUrl)
      .set('Accept', 'application/json')
      .query(opts)

    if @token?
      req = req.set('Authorization', "lftoken #{@token}")

    req.end (err, res) =>
      if err?
        @emit 'error', "Error fetching #{opts.resource}. Error: #{err}"
        return callback err, res
      return callback err, res, res.body

  close: () ->


module.exports =
  ChronosConnection: ChronosConnection
