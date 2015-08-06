{EventEmitter} = require 'events'
{Precondition, Condition} = require '../errors.coffee'


###
# This is a simple interface to a cursor when paging in one direction.
# The user subscribes to the readable event, and when readable, may read
# data buffered itself. Explicitly calling `.loadNext` after a readable event
# depends on the datasource backing the cursor.
#
# @event SimplePager#initialized - indicates the cursor has data loaded
#    and paging can begin.
# @type {boolean} - always true.
#
# @event SimplePager#readable - indicates additional data is available
#    in the buffer for reading. Returns the same data as SimplePater#status().
#
# @event SimplePager#end - indicates the cursor is exhausted and `.done()` will
#    return true.
#
# @event SimplePager#error - general error bus for non-recoverable events.
#    in most cases the pager should be disposed of and a new query constructed.
###
class SimplePager extends EventEmitter
  ###
  # @param {Cursor} cursor - an object supporting the cursor interface.
  # @param {Object} [opts] - options
  # @param {boolean} [opts.autoLoad] - immediately fetch the next page on init.
  # @param {number} [opts.size=Infinity] - number of items to read by default when calling `.read()`
  #
  # @fires SimplePager#initialized
  # @fires SimplePager#readable
  # @fires SimplePager#end
  # @fires SimplePager#error
  ###
  constructor: (@cursor, opts={}) ->
    {@autoLoad, @size} = opts
    @autoLoad ?= false
    @size ?= Infinity
    @_initialized = false
    Precondition.checkArgument(@cursor?, true, "cursor cannot be null")
    Precondition.checkArgument(@cursor.on?, true, "cursor must be an eventemitter")
    Precondition.checkArgumentType(@autoLoad, 'boolean', "autoLoad option must be boolean; default: false")

    @cursor.on 'error', (args...) => @emit('error', args...)

    @cursor.on 'readable', (event) =>
      if not @_initialized
        @_initialized = true
        @emit 'initialized', true
      @_updated(event)

    @cursor.on 'end', (event) =>
      @_updated {end: event}
      @emit 'end'

    if @cursor.count() > 0
      @_initialized = true
      @emit 'initialized'
    else if @autoLoad
      @cursor.next()

  _updated: (event) ->
    Precondition.checkArgumentType(event, 'object')
    c = @status()
    c.trigger = event
    @emit 'readable', c

  ###
  # Get a count of buffered items, and metadata about the cursor.
  #
  # @return {object} status
  # @return {number} status.count - number of items available to read in the buffer.
  # @return {boolean} status.estimated - flag indicating more data *may* be available
  #    to read in the future
  # @return {boolean} status.live - indicates the cursor may be passively receiving data.
  ###
  status: ->
    if not @_initialized
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

  ###
  # True if the cursor reports there are no more items.
  ###
  done: ->
    if not @_initialized
      return false
    return not @cursor.hasNext()

  ###
  # Read data buffered in the cursor.
  #
  # @params {object} [opts] - options.
  # @params {number} [opts.size=this.size] - maximum number of items to read.
  # @params {boolean} [opts.loadOnFault=false] - load the next page if no data can be read.
  # @return {array}
  ###
  read: (opts={}) ->
    {size, loadOnFault} = opts
    size ?= @size
    loadOnFault ?= false
    Precondition.checkArgument(typeof size, 'number', 'invalid size')
    Precondition.checkArgument(typeof loadOnFault, 'boolean', 'invalid value for loadOnFault')

    return @_read(size, loadOnFault)

  ###
  # Load the next page of data from the cursor. Exact behavior depends on the
  # particular cursor and backend.
  ###
  loadNextPage: ->
    @cursor.fault()

  ###
  # Read all data from the buffer.
  ###
  readAllBuffered: ->
    return @read({size: Infinity})

  ###
  # To be called to free resources if the pager is discarded or disabled.
  ###
  close: ->
    @cursor.close()

  ###
  # Reserved for future use.
  ###
  save: ->

  ###
  # Reserved for future use.
  ###
  @restore: ->

  _read: (size, fault) ->
    b = @cursor.read(size: size, fault: fault)
    if not b?
      return []
    return b


module.exports =
  SimplePager: SimplePager
