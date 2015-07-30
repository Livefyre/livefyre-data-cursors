# nodejs shim:
if typeof atob is 'undefined'
  atob = require('atob')

module.exports.getUserUrnFromToken = (token) ->
  parts = token.split('.')
  dataPart = parts[1]
  data = JSON.parse(atob(dataPart))
  network = data.domain
  userId = data.user_id
  v = "urn:livefyre:#{network}:user=#{encodeURIComponent(userId)}"
  console.log(v)
  return v

