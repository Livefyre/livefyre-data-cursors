{EventEmitter} = require 'events'
{Precondition, Condition} = require '../errors.coffee'


#
# This a model which supports
#
class SimplePager extends EventEmitter
  constructor: (@pastCursor, opts={}) ->
    {autoLoad, @size} = opts
    autoLoad ?= false
    @_initialized = true
    Precondition.checkArgument(@pastCursor?, true, "past cursor cannot be null")
    Precondition.checkArgument(@pastCursor.on?, true, "past cursor must be an eventemitter")
    Precondition.checkArgumentType(autoLoad, 'boolean', "autoLoad option must be boolean; default true")

    @pastCursor.on 'error', (args...) => @emit('error', args...)

    @pastCursor.on 'readable', (event) =>
      if not @_initialized
        @_initialized = true
        @emit 'initialized'
      @_updated(event)

    @pastCursor.on 'end', (event) =>
      @_updated {end: event}

    # check if the
    if @pastCursor.count() > 0
      @_initialized = true
      @emit 'initialized'
    else if autoLoad
      @pastCursor.next()

  _updated: (event) ->
    Precondition.checkArgumentType(event, 'object')
    c = @count()
    c.trigger = event
    @emit 'readable', c

  count: ->
    if not @_initialized?
      return {
        count: NaN,
        estimated: true
        live: false
      }
    return {
      count: @pastCursor.count()
      estimated: @pastCursor.hasNext()
      live: false
    }

  read: (opts={}) ->
    {size, loadOnFault} = opts
    size ?= @size
    loadOnFault ?= false
    Precondition.checkArgument(typeof size, 'number', 'invalid size')
    Precondition.checkArgument(typeof loadOnFault, 'boolean', 'invalid value for loadOnFault')

    return @_readPast(size, loadOnFault)

  forceFault: ->
    @pastCursor.fault()

  flush: ->
    return @read({size: Infinity})

  close: ->
    @pastCursor.close()

  save: ->

  @restore: ->

  _readPast: (size, fault) ->
    b = @pastCursor.read(size: size, fault: fault)
    if not b?
      return []
    return b


module.exports =
  SimplePager: SimplePager
