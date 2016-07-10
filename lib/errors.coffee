#
# Raised when an operation or function receives an argument that
# has the right type but an inappropriate value, and the situation
# is not described by a more precise exception
#
class ValueError extends Error
  constructor: (@data, @message=null) ->
    @name = "ValueError"
    @message ?= "invalid"


class DataError extends Error
  constructor: (@data, @message=null) ->
    @name = "DataError"
    @message ?= "unexpected data"


Logger =
  error: (name, args...) ->
    console.error("bad things in #{name}", args)
    

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
    Precondition.checkArgument(typeof value, expected, msg? or "#{value} is not of type #{expected}")

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


module.exports =
  Precondition: Precondition
  Condition: Precondition
  ValueError: ValueError
  DataError: DataError
  Logger: Logger
