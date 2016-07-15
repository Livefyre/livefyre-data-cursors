events = require 'events'

class EventEmitter extends events.EventEmitter
  _emit: events.EventEmitter::emit

  emit: (args...) ->
    @_emit.apply(this, args)
    args.unshift('*')
    @_emit.apply(this, args)

module.exports = {
  EventEmitter: EventEmitter
}