{InterfaceDescriptor, Precondition, CancellationError} = require '../errors.coffee'
{EventEmitter} = require '../events.coffee'
{Pause} = require '../pause.coffee'

###*
  A state machine that which provides a promise via #pause
  that yields after a period based on the current state. This simplifies
  the mechanics and accounting to meter rates of promise completion in err'ing
  or backoff conditions.
###
class FlowRegulator extends EventEmitter

  constructor: (states) ->
    Precondition.checkArgumentType(states, 'object')
    InterfaceDescriptor::describe states, 'states', (has) ->
      has.property 'default', 'object'
      for state, val of states
        InterfaceDescriptor::describe val, "states.#{state}", (shas) ->
          shas.method 'reset'
          shas.method 'next'
          shas.method 'max'
          shas.method 'current'

    @states = states
    @_currentState = 'default'
    @_promise = null

  setState: (name, advance=true) ->
    Precondition.checkArgument(@states[name]?, true, "unknown state: #{name}")
    if @_currentState == name
      return
    # 0. reset
    rinfo = @_reset()
    oldstate = @_currentState
    @_currentState = name
    i = 0
    while @current() < rinfo.previous and @current() < @states[@_currentState].max()
      if i > 100
        Precondition.illegalState "too many iterations, transitioning from #{oldstate} (#{rinfo.previous}) to #{newstate} (#{@current()}"
      @next()
      i++
    rinfo.current = @current()
    rinfo.newState = name
    @_promise?.set rinfo.current
    @emit 'stateChanged', rinfo

  backoff: ->
    oldval = @states[@_currentState].current()
    newval = @states[@_currentState].next()
    info = {
      oldState: @_currentState
      newState: @_currentState
      previous: oldval
      current: newval
    }
    @emit 'backoff', info
    @_promise?.set info.current
    return info

  release: ->
    info = @_reset()
    @emit 'released', info

  current: ->
    return @states[@_currentState].current()

  _reset: ->
    s = @states[@_currentState]
    current = s.current()
    s.reset()
    newc = s.current()
    info = {
      oldState: @_currentState
      newState: @_currentState
      previous: current
      current: newc
    }
    return info

  use: (idleMonitor) ->
    InterfaceDescriptor::describe idleMonitor, 'idleMonitor', (has) ->
      has.method 'on'

    last = null
    if @states.hidden?
      idleMonitor.on IdleMonitor::HIDDEN, =>
        last = @_currentState
        @setState 'hidden'

    idleMonitor.on IdleMonitor::ACTIVE, =>
      if last is null
        return

      @setState last
      last = null
      @interrupt()

    if @states.idle?
      @on 'endPause', =>
        if @_currentState == 'idle'
          @backoff()

      idleMonitor.on IdleMonitor::IDLE, =>
        last = @_currentState
        @setState 'idle'

  cancel: ->
    try
      @_promise?.cancel()
      return false
    catch e
      if e instanceof CancellationError
        return true
      throw e

  interrupt: ->
    @_promise?.interrupt()

  pause: (opts={}, args...) ->
    if @_promise?
      Precondition.illegalState 'already paused'
    {duration} = opts
    duration ?= Math.min(@)
    @_promise = new Pause(duration)
    @emit 'beginPause', duration: duration
    return @_promise.then (args)=>
      @_promise = null
      @emit 'endPause'
      return args
    .catch (e) =>
      @_promise = null
      try
        if e instanceof CancellationError
          @emit 'promiseCancelled'
        else
          @emit 'pauseError', e
      finally
        @emit 'endPause'
        throw e


###*
  A mechanism for detecting idle state in browsers to initiate backoff,
  polling or other resource saving techniques.

  @event IdleBrowserMonitor#hidden The current tab was hidden (state change)
  @event IdleBrowserMonitor#active There was activity on the current tab (state change)
  @event IdleBrowserMonitor#idle No activity was observed in recent time (state change)
###
class IdleMonitor extends EventEmitter
  HIDDEN: 'hidden'
  ACTIVE: 'active'
  IDLE: 'idle'

  constructor: (opts={}) ->
    {duration, whileActive} = opts
    duration ?= 60
    whileActive ?= null
    whileActiveInterval = null
    Precondition.checkArgumentType(duration, 'number')
    Precondition.checkOptionType(whileActive, 'function')
    Precondition.checkOptionType(whileActiveInterval, 'number')
    try
# TODO: this could be bad, as a global module, yes?
      ifvisible = require 'ifvisible.js'
      ifvisible.setIdleDuration duration
      ifvisible.on 'statusChanged', (e) =>
        @emit e.status
      if whileActive?
        ifvisible.onEvery(whileActiveInterval, whileActive)
    catch
      console.log('ifvisble.js not requireable')
      if whileActive?
        setTimeout whileActiveInterval, whileActive



class Backoff
  _max: 300

  constructor: (@opts) ->
    @reset()

  current: ->
    val = Math.min(@max(), @_current)
    if @opts?.jitter
      jitter = Math.random() * (@opts.jitter * 2) - @opts.jitter
      val = val + jitter
    return val * 1000

  next: ->
    @_current = @_next()

  max: ->
    return @opts?.max or @_max

  reset: ->
    throw new Error('abstract')

  _next: ->
    throw new Error('abstract')


class LinearBackoff extends Backoff
  init: 0
  increment: 5

  reset: ->
    @_current = @opts?.init or @init

  _next: ->
    @_current = @_current + (@opts?.increment or @increment)
    return @_current

###*
  Effectively moves the origin back before it begins
  backoff.
###
class Delay
  constructor: (@backoff, @count) ->
    @reset()

  current: -> @backoff.current()

  next: ->
    if @_count < @count
      @_count++
      return @backoff.current()
    return @backoff.next()

  max: ->
    return @backoff.max()

  reset: ->
    @_count = 0
    @backoff.reset()


class GeometricBackoff extends Backoff
  base: 2
  exp: 2

  reset: ->
    @_exp = @opts?.exp or @exp
    @_current = @_next()

  _next: ->
    try
      return Math.pow(@opts?.base or @base, @_exp)
    finally
      @_exp++


module.exports =
  FlowRegulator: FlowRegulator
  LinearBackoff: LinearBackoff
  GeometricBackoff: GeometricBackoff
  Delay: Delay
  IdleMonitor: IdleMonitor
