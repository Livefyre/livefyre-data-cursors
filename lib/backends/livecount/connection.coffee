{BaseConnection} = require '../base/connection.coffee'
{Precondition} = require '../../errors.coffee'
request = require 'superagent'


class LivecountConnection extends BaseConnection
  ENVIRONMENTS:
    'fy.re': 'https://lc.fy.re'
    'fyre': 'https://lc.fyre'
    'qa': 'https://lc.qa-ext.livefyre.com'
    'uat': 'https://lc.t402.livefyre.com'
    'production': 'https://lc.livefyre.com'

  constructor: (@environment='production') ->
    Precondition.checkArgument(@ENVIRONMENTS[@environment]?,
      "#{@environment} is not a valid value")
    @baseUrl = @ENVIRONMENTS[@environment]
    @token = null
    # don't term on errors:
    @on 'error', ->

  openCursor: (query) ->
    Precondition.checkArgumentType(query, 'object', "invalid query object: #{query}")
    return new LivecountCursor(this, query)

  fetch: (host, path, params, callback) ->
    Precondition.equal(typeof path, 'string')
    Precondition.equal(typeof params, 'object')
    Precondition.equal(typeof callback, 'function')
    if not host?
      host = @baseUrl
    url = "#{host}#{path}"
    req = request.get(url)
      .set('Accept', 'application/json')
      .query(params)
      .timeout(10000)
    req.end (err, res) =>
      @emit 'error', "Error fetching #{url}, #{err}"
      callback {
        err: err,
        data: if not err then res.body else res
        res: res
      }

#fyre.conv.client.LivecountClient::start = ->
#  goog.asserts.assert @collectionId
#  if @routed
#    data['routed'] = '1'
#  else if @timeout
#    data['timeout'] = '1'
#  if fyre.conv.user.id
#    data['userId'] = fyre.conv.user.id
#  goog.object.extend data, @extraQueryArgs_
#  @xhr.send data
#  return
#
#fyre.conv.client.LivecountClient::handleLivecountSuccess = (response, event) ->
#  if @stopped
#    return
#  data = response['data']
#  @timeout = false
#  switch response['code']
#    when 302
#      @routed = data
#      @start()
#    when 500
#      @routed = false
#      @start()
#    else
#      @success data
#  return

module.exports =
  LivecountConnection: LivecountConnection
