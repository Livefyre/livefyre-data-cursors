{EventEmitter} = require 'events'
{Precondition, Condition} = require '../errors.coffee'


#
# This is a simple interface to a cursor when paging in one direction.
# The user subscribes to the readable event, and when readable, may read
# data buffered itself. Explicitly calling `.loadNext` after a readable event
# depends on the datasource backing the cursor.
#
class SimplePager extends EventEmitter
  #
  # @param {Cursor} cursor - an object supporting the cursor interface.
  # @param {Object} [opts] - options
  # @param {boolean} [opts.autoLoad] - immediately fetch the next page on init.
  # @param {size} [opts.size] - number of items to read by default when calling `.read()`
  #
  constructor: (@cursor, opts={}) ->
    {autoLoad, @size} = opts
    autoLoad ?= false
    @_initialized = true
    Precondition.checkArgument(@cursor?, true, "cursor cannot be null")
    Precondition.checkArgument(@cursor.on?, true, "cursor must be an eventemitter")
    Precondition.checkArgumentType(autoLoad, 'boolean', "autoLoad option must be boolean; default: false")

    @cursor.on 'error', (args...) => @emit('error', args...)

    @cursor.on 'readable', (event) =>
      if not @_initialized
        @_initialized = true
        @emit 'initialized'
      @_updated(event)

    @cursor.on 'end', (event) =>
      @_updated {end: event}
      @emit 'end'

    if @cursor.count() > 0
      @_initialized = true
      @emit 'initialized'
    else if autoLoad
      @cursor.next()

  _updated: (event) ->
    Precondition.checkArgumentType(event, 'object')
    c = @count()
    c.trigger = event
    @emit 'readable', c

  #
  # Get a count of buffered items, and metadata about the cursor.
  #
  count: ->
    if not @_initialized?
      return {
        count: NaN,
        estimated: true
        live: false
      }
    return {
      count: @cursor.count()
      estimated: @cursor.hasNext()
      live: false
    }

  read: (opts={}) ->
    {size, loadOnFault} = opts
    size ?= @size
    loadOnFault ?= false
    Precondition.checkArgument(typeof size, 'number', 'invalid size')
    Precondition.checkArgument(typeof loadOnFault, 'boolean', 'invalid value for loadOnFault')

    return @_read(size, loadOnFault)

  loadNext: ->
    @cursor.fault()

  readAllBuffered: ->
    return @read({size: Infinity})

  close: ->
    @cursor.close()

  save: ->

  @restore: ->

  _read: (size, fault) ->
    b = @cursor.read(size: size, fault: fault)
    if not b?
      return []
    return b


module.exports =
  SimplePager: SimplePager
