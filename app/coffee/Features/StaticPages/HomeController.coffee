logger = require('logger-sharelatex')
_ = require('underscore')
Settings = require('settings-sharelatex')

Path = require "path"
fs = require "fs"

ErrorController = require "../Errors/ErrorController"

homepageExists = fs.existsSync Path.resolve(__dirname + "/../../../views/external/home.jade")

module.exports = HomeController =
	index : (req,res)->
		if req.session.user
			if req.query.scribtex_path?
				res.redirect "/project?scribtex_path=#{req.query.scribtex_path}"
			else
				res.redirect '/project'
		else
			HomeController.home(req, res)

	home: (req, res)->
		if homepageExists
			res.render 'external/home'
		else
			if (Settings.ldap)
				res.redirect "/register"
			else
				res.redirect "/login"

	externalPage: (page, title) ->
		return (req, res, next = (error) ->) ->
			path = Path.resolve(__dirname + "/../../../views/external/#{page}.jade")
			fs.exists path, (exists) -> # No error in this callback - old method in Node.js!
				if exists
					res.render "external/#{page}.jade",
						title: title
				else
					ErrorController.notFound(req, res, next)
