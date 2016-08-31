#
# Raised when an operation or function receives an argument that
# has the right type but an inappropriate value, and the situation
# is not described by a more precise exception
#
class ValueError extends Error
  constructor: (@data, @message=null) ->
    @name = "ValueError"
    @message ?= "invalid"

  toString: ->
    "#{@name}: #{@message}"

class DataError extends Error
  constructor: (@data, @message=null) ->
    @name = "DataError"
    @message ?= "unexpected data"

  toString: ->
    "#{@name}: #{@message}"

class CancellationError extends Error
  name = "CancellationError"
  constructor: (@message="operation cancelled") ->

  toString: ->
    "#{@name}: #{@message}"



Logger =
  error: (name, args...) ->
    console.error("bad things in #{name}", args)


class InterfaceDescriptor
  constructor: (@obj, @name) ->
    Precondition.checkArgumentType(@obj, 'object')
    Precondition.checkArgumentType(@name, 'string')

  method: (method) ->
    if not @obj?
      throw new ValueError(@obj, "#{@name} is not an object")
    if typeof @obj[method] != 'function'
      throw new ValueError(@obj.method, "#{@name}##{method} is not a function")

  property: (property, type, precondition) ->
    if not @obj?
      throw new ValueError(@obj, "#{@name} is not an object")
    if typeof @obj[property] != type
      throw new ValueError(@obj, "#{@name}##{property} is not #{type}, is: #{typeof(@obj[property])}")

    if precondition? and not precondition(@obj[property])
      throw new ValueError(@obj, "#{@name}##{property} failed precondition")

  requirement: (property, desc, precondition) ->
    if precondition? and not precondition(@obj[property])
      throw new ValueError(@obj, "#{@name}##{property} failed precondition: #{desc}")


InterfaceDescriptor::describe = (obj, name, callback) ->
  has = new InterfaceDescriptor(obj, name)
  callback(has)


Precondition =
  equal: (actual, expected, msg=null) ->
    if actual is not expected
      throw new ValueError(actual, msg or "#{actual} != #{expected}")

  checkArgument: (expr_value, value, msg=null) ->
    if not expr_value? or expr_value is false
      throw new ValueError(value, msg)

  checkArgumentType: (value, expected, msg=null) ->
    if expected is 'array'
      return Precondition.checkArgument Array.isArray(value), true, "#{expected} is not an array"
    Precondition.checkArgument(typeof(value) == expected, expected, msg? or "#{value} is not of type #{expected}")

  checkOptionType: (value, expected, msg=null) ->
    if value == undefined
      return
    if typeof(value) != expected
      throw new ValueError(value, "#{value} is not of type #{expected}")

  illegalState: (msg) ->
    throw new Error(msg)

  _getEntryPoint: (key) ->
    stack = new Error().stack.split(/\n/)
    stack.shift()
    stack.shift()
    while (frame = stack[0]) and (frame? and frame.indexOf(key) != -1)
      stack.shift()
    return stack.join("\n")

_decorate = (key, func) ->
  return (args...) ->
    passed = false
    try
      func(args...)
      passed = true
    finally
      if not passed
        console.log("Precondition `#{key}` failed:\n#{Precondition._getEntryPoint(key)}\nCaller:#{arguments.callee.caller.toString()}")

for key of Precondition
  if key is '_getEntryPoint'
    continue
  f = Precondition[key]
  Precondition[key] = _decorate(key, f)


class Meter
  constructor: ->

  inc: (keys...) ->
    for key in keys
      this[key] ?= 0
      ++this[key]

  val: (key, set=0) ->
    this[key] ?= set

  reset: (keys...) ->
    for key in keys
      @val key, 0

  collect: (values) ->
    for key, val of this
      if val > 0
        values[key] = val
    return values


module.exports =
  Precondition: Precondition
  InterfaceDescriptor: InterfaceDescriptor
  Condition: Precondition
  ValueError: ValueError
  DataError: DataError
  CancellationError: CancellationError
  Logger: Logger
  Meter: Meter
