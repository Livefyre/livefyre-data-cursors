{EventEmitter} = require 'events'
{Precondition, Condition} = require '../../errors.coffee'

ReadMode =
  natural: 0
  head: 1
  tail: -1


class BidirectionalStream extends EventEmtter
  constructor: (@pastCursor, @futureCursor, opts={}) ->
    {autoLoad, @size} = opts
    autoLoad ?= false
    @_initialized = true
    Precondition.checkArgument(@futureCursor?, true, "future cursor cannot be null")
    Precondition.checkArgument(@cursor?, true, "past cursor cannot be null")
    Precondition.checkArgument(@futureCursor.on?, true, "future cursor must be an eventemitter")
    Precondition.checkArgument(@cursor.on?, true, "past cursor must be an eventemitter")
    Precondition.checkArgumentType(autoLoad, 'boolean', "autoLoad option must be boolean; default true")

    @cursor.on 'error', (args...) =>
    @futureCursor.on 'error', (args...) =>

    @cursor.on 'readable', (event) =>
      if not @_initialized
        @_initialized = true
        @emit 'initialized'
      @_updated(event.data)

    @cursor.on 'end', (event) =>
      @_updated []

    @futureCursor.on 'readable', (event) =>
      if not @_initialized?
        @emit 'trace', 'the future is now', event
        return
      @_updated(event.data)

    # check if the
    if @cursor.count() > 0
      @_initialized = true
      @emit 'initialized'
    else if autoLoad
      @cursor.next()

  _updated: (data) ->
    Precondition.checkArgumentType(data, 'array')
    c = @count()
    c.data = data
    @emit 'readable', c

  count: ->
    live = if @futureCursor.isLive? then @futureCursor.isLive() else false
    # don't return a count until we've
    if not @_initialized?
      return {
        count: NaN,
        estimated: true
        live: live
      }
    return {
      count: @cursor.count() + @futureCursor.count()
      estimated: @cursor.hasNext()
      live: live
    }

  read: (opts={}) ->
    {size, mode, loadOnFault} = opts
    size ?= @size
    mode ?= 'natural'
    loadOnFault ?= false
    Precondition.checkArgument(ReadMode[mode]?, true, "invalid mode: #{mode}")
    Precondition.checkArgument(typeof size, 'number', 'invalid size')

    if mode is ReadMode.tail # going back in time
      return @_read(size, loadOnFault)

    if mode is ReadMode.head # going into the future, read from stream.
      return @futureCursor.read(size: size)

    if mode is ReadMode.natural
      # read from head and then tail!
      b = @futureCursor.read(size: size)
      size =- b.length
      if size > 0
        b.push(@_read(size, loadOnFault)...)
      return b
    Precondition.illegalState("how did we get here? #{mode}")

  flush: ->
    return @read({size: Infinity})

  close: ->
    @futureCursor.close()
    @cursor.close()

  save: ->

  @restore: ->

  _readPast: (size, fault) ->
    b = @cursor.read(size: size, fault: fault)
    if b is null
      return []
    if b is undefined
      return []
    return b


module.exports =
  BidirectionalStream: BidirectionalStream
  ReadMode: ReadMode
