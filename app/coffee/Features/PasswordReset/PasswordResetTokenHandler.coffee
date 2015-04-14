Settings = require('settings-sharelatex')
redis = require("redis-sharelatex")
rclient = redis.createClient(Settings.redis.web)
crypto = require("crypto")
logger = require("logger-sharelatex")

ONE_HOUR_IN_S = 60 * 60

buildKey = (token)-> return "password_token:#{token}"

module.exports =

	getNewToken: (user_id, options = {}, callback)->
		# options is optional
		if typeof options == "function"
			callback = options
			options = {}
		expiresIn = options.expiresIn or ONE_HOUR_IN_S
		logger.log user_id:user_id, "generating token for password reset"
		token = crypto.randomBytes(32).toString("hex")
		multi = rclient.multi()
		multi.set buildKey(token), user_id
		multi.expire buildKey(token), expiresIn
		multi.exec (err)->
			callback(err, token)

	getUserIdFromTokenAndExpire: (token, callback)->
		logger.log token:token, "getting user id from password token"
		multi = rclient.multi()
		multi.get buildKey(token)
		multi.del buildKey(token)
		multi.exec (err, results)->
			callback err, results[0]

