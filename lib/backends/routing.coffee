{ConsistentHashing} = require '../hash/consistent.coffee'
{Precondition, InterfaceDescriptor} = require '../errors.coffee'
{Promise} = require 'es6-promise'


###*
# Skips routing, uses the base URL
###
class OriginRouter
  route: (cursor, connection) ->
    Precondition.checkArgumentType(connection.baseUrl, 'string')
    return Promise.resolve({
      url: connection.baseUrl
      reject: () ->
        console.log 'No other connections known: ' + connection.baseUrl
    })

###*
# Clientside router. Handles failures and re-routing.
###
class ClientsideRouter
  constructor: (@selector, @moveAfterNErrors=5) ->
    Precondition.checkArgumentType(@moveAfterNErrors, 'number')
    Precondition.checkArgumentType(@selector.prototype, 'object', 'Selector argument is not a class')
    Precondition.checkArgumentType(@selector.prototype?.select, 'function',
      'Selector prototype does not have a `select` function')
    Precondition.checkArgumentType(@selector.prototype?.shouldRefresh, 'function',
      'Selector prototype does not have a `shouldRefresh`')
    @_selector = null
    @_selected = null
    @move = null

  route: (cursor, connection, move=null) ->
    InterfaceDescriptor::describe cursor, 'cursor', (has) ->
      has.property 'meter', 'object'
      has.method 'emit'
    InterfaceDescriptor::describe connection, 'connection', (has) ->
      has.method 'getServers'

    # 0. move if we're having problems
    move = move or (cursor.meter.seqErrors > 0 and cursor.meter.seqErrors % @moveAfterNErrors == 0)
    return @_route(cursor, connection, move)

  _route: (cursor, connection, move) ->
    if not @_selector?
      @_selector ?= connection.getServers(cursor: cursor).then (list) =>
        cursor.emit 'newSelector'
        return new @selector(list, cursor, connection)

    if not move and @_selected?
      return Promise.resolve(@_selected)

    @_selected = Promise.resolve(@_selector).then (selector) =>
      # throw the whole thing away, and start a new?
      if selector.shouldRefresh()
        @_selector = null
        @_selected = null
        return @_route(cursor, connection, false)
      {url, reject} = selector.select()
      if move
        reject()
        cursor.emit 'serverRejected', url
        @_selected = null
        return @_route(cursor, connection, false)
      rejector = =>
        reject()
        cursor.emit 'serverRejected', url
        @_selected = null

      return {
        url: url
        reject: rejector
      }
    return @_selected


class BaseSelector
  constructor: (@list) ->
    Precondition.checkArgumentType(@list, 'array')
    @initialSize = @list.length

  select: ->
    idx = @choose()
    return {
      url: @list[idx]
      reject: @_remove.bind(this, idx)
    }

  shouldRefresh: ->
    @list.length <= 0

  _remove: (idx) ->
    @list.splice(idx, 1)[0]


class RandomSelector extends BaseSelector
  choose: ->
    return Math.floor(Math.random() * @list.length)


class ConsistentSelector
  constructor: (list, cursor) ->
    Precondition.checkArgumentType(list, 'array')
    InterfaceDescriptor::describe cursor, 'cursor', (has) ->
      has.method 'collectRoutingParams'

    @initialSize = list.length
    obj = {}
    cursor.collectRoutingParams(obj)
    salt = @_urlencode(obj)
    @_hasher = new ConsistentHashing(list, salt: salt)

  select: ->
    item = @_hasher.getNode(@key)
    return {
      reject: @_hasher.removeNode.bind(this, item)
      url: item
    }

  shouldRefresh: ->
    @_hasher.nodes.length <= 0

  _urlencode: (obj) ->
    str = []
    for p of obj
      if obj.hasOwnProperty(p)
        str.push encodeURIComponent(p) + '=' + encodeURIComponent(obj[p])
    str.join '&'


module.exports =
  OriginRouter: OriginRouter
  ClientsideRouter: ClientsideRouter
  BaseSelector: BaseSelector
  RandomSelector: RandomSelector
  ConsistentSelector: ConsistentSelector

