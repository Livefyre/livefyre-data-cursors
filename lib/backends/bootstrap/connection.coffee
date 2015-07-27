{BaseConnection} = require '../base/connection.coffee'


class BootstrapConnection extends BaseConnection
  ENVIRONMENTS:
    'fy.re': 'https://bootstrap.fy.re'
    'fyre': 'https://bootstrap.fyre'
    'qa': 'https://bootstrap.qa-ext.livefyre.com'
    'uat': 'https://bootstrap.t402.livefyre.com'
    'production': 'https://bootstrap.livefyre.com'

  constructor: (@environment, opts={}) ->
    Precondition.checkArgument(@ENVIRONMENTS[@environment]?,
      "#{@environment} is not a valid value")
    {@version, @serviceName} = opts
    @serviceName ?= 'bootstrap'
    @version ?= 'v3.1'
    @baseUrl = @ENVIRONMENTS[@environment]

    @on 'error', ->

  openCursor: (query) ->
    Precondition.checkArgumentType(query, 'object', "invalid query object: #{query}")
    opts = query.opts or {}
    delete query.opts


class BootstrapCursor extends EventEmitter
  constructor: (@client, @query, opts={}) ->
  {@cursor} = opts
  @cursor ?= null
  @buffer = []
  Precondition.checkArgumentType(@query, 'object', "invalid query value: #{@query}")
  Precondition.checkArgumentType(@query.resource, 'string', "invalid query.resource value: #{@query.resource}")
  Precondition.checkArgument(@query.resource.indexOf('urn:') == 0, true,
    "invalid query.resource value; expected URN, got query: #{@query.resource.indexOf('urn:')}")


CollectionQuery = (urn) ->
  [_xx, _xx, networkId, site, article] = urn.split(/:/)
  article = decodeURIComponent(article.split('=', 2)[1])
  site = site.split('=', 2)[1]
  env = null
  switch @environment
    when 'staging' then env = 't402'
    when 'qa' then env = 'qa'

  path = [
    "/bs3/"
    @version
    "/"
    if env? then "#{env}/" else ''
    networkId
    "/"
    site
    "/"
    article
    "/"
  ]
  return path: path.join('')
    page: 'init'


