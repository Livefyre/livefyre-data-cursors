{ConsistentHashing} = require('../../lib/hash/consistent.coffee')
assert = require('chai').assert

describe "ConsistentHashing", ->
  it "#getNode() should hash deterministically", ->
    nodes = [
      'stream1'
      'stream2'
      'stream3'
      'stream4'
    ]
    hash = new ConsistentHashing(nodes)
    assert.equal hash.getNode('a'), 'stream3'
    assert.equal hash.getNode('b'), 'stream2'
    assert.equal hash.getNode('c'), 'stream3'
    assert.equal hash.getNode('d'), 'stream4'
    assert.equal hash.getNode('e'), 'stream2'
    assert.equal hash.getNode('f'), 'stream3'

  it "#addNode() #removeNode() should produce deterministic results", ->
    nodes = [
      'stream1'
      'stream2'
    ]
    hash = new ConsistentHashing(nodes)
    assert.equal hash.getNode('baba'), 'stream2'
    hash.addNode 'stream3'
    hash.addNode 'stream4'
    assert.equal hash.getNode('111'), 'stream1'
    assert.equal hash.getNode('abc'), 'stream3'
    assert.equal hash.getNode('def'), 'stream3'
    hash.removeNode 'stream1'
    assert.equal hash.getNode('111'), 'stream2'
    hash.removeNode 'stream3'
    assert.equal hash.getNode('abc'), 'stream2'
    assert.equal hash.getNode('121'), 'stream4'
    return
