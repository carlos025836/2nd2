Settings = require('settings-sharelatex')
User = require("../../models/User").User
UserLocator = require("./UserLocator")

module.exports =

	getUserOrCreateHoldingAccount: (email, callback = (err, user)->)->
		self = @
		UserLocator.findByEmail email, (err, user)->
			if user?
				callback(err, user)
			else
				self.createNewUser email:email, holdingAccount:true, callback

	createNewUser: (opts, callback)->
		user = new User()
		user.email = opts.email
		user.holdingAccount = opts.holdingAccount

		username = opts.email.match(/^[^@]*/)
		if username?
			user.first_name = username[0]
		else
			user.first_name = ""
		user.last_name = ""
		if Settings.requireRegistrationConfirmation
			user.confirmed = false
		else
			user.confirmed = true


		user.save (err)->
			callback(err, user)
