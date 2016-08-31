md5 = require('md5-js')

###*
# Consistent Hashing for Javascript.
# Maps keys consistently onto the given nodes.
# Adapted for Google Closure from an NPM module:
# https://github.com/dakatsuka/node-consistent-hashing
# @param {Array.<string>} nodes
# @param {Object=} options
# @constructor
###
class ConsistentHashing
  constructor: (nodes, options={}) ->
    @ring = {}
    @keys = []
    @nodes = []
    {@replicas, @salt} = options
    @salt = if @salt then "#{@crypto(@salt)}:" else ''
    @replicas ?= 160
    i = 0
    while i < nodes.length
      @addNode nodes[i]
      i++
    return

  ###* @param {string} node ###
  addNode: (node) ->
    @nodes.push node
    i = 0
    while i < @replicas
      key = @crypto(node + ':' + i)
      @keys.push key
      @ring[key] = node
      i++
    @keys.sort()
    return

  ###* @param {string} node ###
  removeNode: (node) ->
    i = 0
    while i < @nodes.length
      if @nodes[i] == node
        @nodes.splice i, 1
        i--
      i++
    i = 0
    while i < @replicas
      key = @crypto(node + ':' + i)
      delete @ring[key]
      j = 0
      while j < @keys.length
        if @keys[j] == key
          @keys.splice j, 1
          j--
        j++
      i++
    return

  ###*
  # @param {string} key
  # @return {string}
  ###
  getNode: (key) ->
    if @getRingLength() == 0
      return 0
    hash = @crypto(key)
    pos = @getNodePosition(hash)
    @ring[@keys[pos]]

  ###*
  # @param {string} hash
  # @return {number}
  ###
  getNodePosition: (hash) ->
    rlen = @getRingLength()
    upper = rlen - 1
    lower = 0
    idx = 0
    comp = 0
    if upper == 0
      return 0
    while lower <= upper
      idx = Math.floor((lower + upper) / 2)
      comp = @compare(@keys[idx], hash)
      if comp == 0
        return idx
      else if comp > 0
        upper = idx - 1
      else
        lower = idx + 1
    if upper < 0
      upper = rlen - 1
    upper

  ###* @return {number} ###
  getRingLength: ->
    Object.keys(@ring).length

  ###*
  # @param {number} v1
  # @param {number} v2
  # @return {number}
  ###
  compare: (v1, v2) ->
    if v1 > v2 then 1 else if v1 < v2 then -1 else 0

  ###*
  # @param {string} str
  # @return {string}
  ###
  crypto: (str) ->
    return @salt + md5(str)

module.exports =
  ConsistentHashing: ConsistentHashing