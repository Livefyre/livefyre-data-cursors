{Precondition, CancellationError} = require './errors.coffee'
{Promise} = require 'es6-promise'


class Pause
  PAUSED: 1
  CANCELLED: 2
  RUN: 3

  constructor: (@duration, args...) ->
    Precondition.checkArgumentType(@duration, 'number')
    @state = @PAUSED
    @args = args
    @_start = new Date().getTime()
    @_promise = new Promise (resolve, reject) =>
      @_resolve = resolve
      @_reject = reject
      @_timeout = setTimeout @run.bind(this), @duration

  extend: (amount) ->
    if @state != @PAUSED
      return
    Precondition.checkArgumentType(amount, 'number')
    remaining = @duration - (new Date().getTime() - @_start)
    @duration = Math.max(amount + remaining, 0)
    @_updateTimeout(@duration)

  set: (amount) ->
    if @state != @PAUSED
      return
    Precondition.checkArgumentType(amount, 'number')
    elapsed = (new Date().getTime() - @_start)
    @duration = Math.max(amount - elapsed, 0)
    @_updateTimeout(@duration)

  _updateTimeout: (remaining) ->
    if remaining > 0
      clearTimeout @_timeout
      @_timeout = setTimeout @run.bind(this), remaining
      return
    # otherwise, run immediately
    @run()

  then: (next) ->
    return @_promise.then next

  catch: (next) ->
    return @_promise.catch next

  interrupt: ->
    @run()

  cancel: ->
    @run(true)

  run: (cancel=false) ->
    if @state is @CANCELLED and cancel is true
      throw new Error 'cancelled'

    if @state is @RUN
      return
    try
      if cancel is true
        @state = @CANCELLED
        throw new CancellationError
      @state = @RUN
      @_resolve(@args)
    catch e
      @_reject e
      throw e


module.exports =
  Pause: Pause
