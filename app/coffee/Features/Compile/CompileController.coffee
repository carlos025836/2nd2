Metrics = require "../../infrastructure/Metrics"
Project = require("../../models/Project").Project
CompileManager = require("./CompileManager")
ClsiManager = require("./ClsiManager")
logger  = require "logger-sharelatex"
request = require "request"
Settings = require "settings-sharelatex"
AuthenticationController = require "../Authentication/AuthenticationController"
UserGetter = require "../User/UserGetter"

module.exports = CompileController =
	compile: (req, res, next = (error) ->) ->
		res.setTimeout(5 * 60 * 1000)
		project_id = req.params.Project_id
		isAutoCompile = !!req.query?.auto_compile
		settingsOverride = req.body?.settingsOverride ? {};
		logger.log "root doc overriden" if settingsOverride.rootDoc_id?
		AuthenticationController.getLoggedInUserId req, (error, user_id) ->
			return next(error) if error?
			UserGetter.getUser user_id, {"features.compileGroup":1, "features.compileTimeout":1}, (err, user)->
				settingsOverride.timeout = user?.features?.compileTimeout || Settings.defaultFeatures.compileTimeout
				settingsOverride.compiler = user?.features?.compileGroup || Settings.defaultFeatures.compileGroup
				req.session.compileGroup = settingsOverride.compiler
				CompileManager.compile project_id, user_id, { isAutoCompile, settingsOverride }, (error, status, outputFiles) ->
					return next(error) if error?
					res.contentType("application/json")
					res.send 200, JSON.stringify {
						status: status
						outputFiles: outputFiles
					}

	downloadPdf: (req, res, next = (error) ->)->
		Metrics.inc "pdf-downloads"
		project_id = req.params.Project_id
		Project.findById project_id, {name: 1}, (err, project)->
			res.contentType("application/pdf")
			if !!req.query.popupDownload
				logger.log project_id: project_id, "download pdf as popup download"
				res.header('Content-Disposition', "attachment; filename=#{project.getSafeProjectName()}.pdf")
			else
				logger.log project_id: project_id, "download pdf to embed in browser"
				res.header('Content-Disposition', "filename=#{project.getSafeProjectName()}.pdf")
			CompileController.proxyToClsi("/project/#{project_id}/output/output.pdf", req, res, next)

	deleteAuxFiles: (req, res, next) ->
		project_id = req.params.Project_id
		ClsiManager.deleteAuxFiles project_id, (error) ->
			return next(error) if error?
			res.send(200)

	compileAndDownloadPdf: (req, res, next)->
		project_id = req.params.project_id
		CompileManager.compile project_id, null, {}, (err)->
			if err?
				logger.err err:err, project_id:project_id, "something went wrong compile and downloading pdf"
				res.send 500
			url = "/project/#{project_id}/output/output.pdf"
			CompileController.proxyToClsi url, req, res, next

	getFileFromClsi: (req, res, next = (error) ->) ->
		CompileController.proxyToClsi("/project/#{req.params.Project_id}/output/#{req.params.file}", req, res, next)

	proxySync: (req, res, next = (error) ->) ->
		CompileController.proxyToClsi(req.url, req, res, next)

	proxyToClsi: (url, req, res, next = (error) ->) ->
		if req.session.compileGroup == "priority"
			compilerUrl = Settings.apis.clsi_priority.url
		else
			compilerUrl = Settings.apis.clsi.url
		url = "#{compilerUrl}#{url}"
		logger.log url: url, "proxying to CLSI"
		oneMinute = 60 * 1000
		proxy = request(url: url, method: req.method, timeout: oneMinute)
		proxy.pipe(res)
		proxy.on "error", (error) ->
			logger.warn err: error, url: url, "CLSI proxy error"

	
