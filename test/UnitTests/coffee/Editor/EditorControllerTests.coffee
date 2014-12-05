SandboxedModule = require('sandboxed-module')
sinon = require('sinon')
require('chai').should()
expect = require("chai").expect

modulePath = require('path').join __dirname, '../../../../app/js/Features/Editor/EditorController'
MockClient = require "../helpers/MockClient"
assert = require('assert')

describe "EditorController", ->
	beforeEach ->
		@project_id = "test-project-id"
		@project =
			_id: @project_id
			owner_ref:{_id:"something"}


		@doc_id = "test-doc-id"
		@source = "dropbox"

		@projectModelView = 
			_id: @project_id
			owner:{_id:"something"}

		@user =
			_id: @user_id = "user-id"
			projects: {}

		@rooms = {}
		@io =
			sockets :
				clients : (room_id) =>
					@rooms[room_id]
		@DocumentUpdaterHandler = {}
		@ProjectOptionsHandler =
			setCompiler : sinon.spy()
			setSpellCheckLanguage: sinon.spy()
		@ProjectEntityHandler = 
			flushProjectToThirdPartyDataStore:sinon.stub()
		@ProjectEditorHandler =
			buildProjectModelView : sinon.stub().returns(@projectModelView)
		@Project =
			findPopulatedById: sinon.stub().callsArgWith(1, null, @project)
		@LimitationsManager = {}
		@AuthorizationManager = {}
		@client = new MockClient()

		@settings = 
			apis:{thirdPartyDataStore:{emptyProjectFlushDelayMiliseconds:0.5}}
			redis: web:{}
		@dropboxProjectLinker = {}
		@callback = sinon.stub()
		@ProjectDetailsHandler = 
			setProjectDescription:sinon.stub()
		@CollaboratorsHandler = 
			removeUserFromProject: sinon.stub().callsArgWith(2)
			addUserToProject: sinon.stub().callsArgWith(3)
		@ProjectDeleter =
			deleteProject: sinon.stub()
		@ConnectedUsersManager =
			markUserAsDisconnected:sinon.stub()
			updateUserPosition:sinon.stub()
		@LockManager =
			getLock : sinon.stub()
			releaseLock : sinon.stub()
		@EditorController = SandboxedModule.require modulePath, requires:
			"../../infrastructure/Server" : io : @io
			'../Project/ProjectEditorHandler' : @ProjectEditorHandler
			'../Project/ProjectEntityHandler' : @ProjectEntityHandler
			'../Project/ProjectOptionsHandler' : @ProjectOptionsHandler
			'../Project/ProjectDetailsHandler': @ProjectDetailsHandler
			'../Project/ProjectDeleter' : @ProjectDeleter
			'../Project/ProjectGetter' : @ProjectGetter = {}
			'../User/UserGetter': @UserGetter = {}
			'../Collaborators/CollaboratorsHandler': @CollaboratorsHandler
			'../DocumentUpdater/DocumentUpdaterHandler' : @DocumentUpdaterHandler
			'../Subscription/LimitationsManager' : @LimitationsManager
			'../Security/AuthorizationManager' : @AuthorizationManager
			'../../models/Project' : Project: @Project
			"settings-sharelatex":@settings
			'../Dropbox/DropboxProjectLinker':@dropboxProjectLinker
			'./EditorRealTimeController':@EditorRealTimeController = {}
			"../../infrastructure/Metrics": @Metrics = { inc: sinon.stub() }
			"../TrackChanges/TrackChangesManager": @TrackChangesManager = {}
			"../ConnectedUsers/ConnectedUsersManager":@ConnectedUsersManager
			"../../infrastructure/LockManager":@LockManager
			'redis-sharelatex':createClient:-> auth:->
			"logger-sharelatex": @logger =
				log: sinon.stub()
				err: sinon.stub()

	describe "joinProject", ->
		beforeEach ->
			sinon.spy(@client, "set")
			sinon.spy(@client, "get")
			@AuthorizationManager.setPrivilegeLevelOnClient = sinon.stub()
			@EditorRealTimeController.emitToRoom = sinon.stub()
			@ConnectedUsersManager.updateUserPosition.callsArgWith(4)
			@ProjectDeleter.unmarkAsDeletedByExternalSource = sinon.stub()

		describe "when authorized", ->
			beforeEach ->
				@EditorController.buildJoinProjectView = sinon.stub().callsArgWith(2, null, @projectModelView, "owner")
				@EditorController.joinProject(@client, @user, @project_id, @callback)

			it "should set the privilege level on the client", ->
				@AuthorizationManager.setPrivilegeLevelOnClient
					.calledWith(@client, "owner")
					.should.equal.true

			it "should add the client to the project channel", ->
				@client.join.calledWith(@project_id).should.equal true

			it "should set the project_id of the client", ->
				@client.set.calledWith("project_id", @project_id).should.equal true

			it "should mark the user as connected with the ConnectedUsersManager", ->
				@ConnectedUsersManager.updateUserPosition.calledWith(@project_id, @client.id, @user, null).should.equal true

			it "should return the project model view, privilege level and protocol version", ->
				@callback.calledWith(null, @projectModelView, "owner", @EditorController.protocolVersion).should.equal true
		
		describe "when not authorized", ->
			beforeEach ->
				@EditorController.buildJoinProjectView = sinon.stub().callsArgWith(2, null, null, false)
				@EditorController.joinProject(@client, @user, @project_id, @callback)

			it "should not set the privilege level on the client", ->
				@AuthorizationManager.setPrivilegeLevelOnClient
					.called.should.equal false

			it "should not add the client to the project channel", ->
				@client.join.called.should.equal false

			it "should not set the project_id of the client", ->
				@client.set.called.should.equal false

			it "should return an error", ->
				@callback.calledWith(sinon.match.truthy).should.equal true
				
		describe "when the project is marked as deleted", ->
			beforeEach ->
				@projectModelView.deletedByExternalDataSource = true
				@EditorController.buildJoinProjectView = sinon.stub().callsArgWith(2, null, @projectModelView, "owner")
				@EditorController.joinProject(@client, @user, @project_id, @callback)	
			
			it "should remove the flag to send a user a message about the project being deleted", ->
				@ProjectDeleter.unmarkAsDeletedByExternalSource
					.calledWith(@project_id)
					.should.equal true
				
	describe "buildJoinProjectView", ->
		beforeEach ->
			@ProjectGetter.getProjectWithoutDocLines = sinon.stub().callsArgWith(1, null, @project)
			@ProjectGetter.populateProjectWithUsers = sinon.stub().callsArgWith(1, null, @project)
			@UserGetter.getUser = sinon.stub().callsArgWith(2, null, @user)
				
		describe "when authorized", ->
			beforeEach ->
				@AuthorizationManager.getPrivilegeLevelForProject =
					sinon.stub().callsArgWith(2, null, true, "owner")
				@EditorController.buildJoinProjectView(@project_id, @user_id, @callback)
				
			it "should find the project without doc lines", ->
				@ProjectGetter.getProjectWithoutDocLines
					.calledWith(@project_id)
					.should.equal true

			it "should populate the user references in the project", ->
				@ProjectGetter.populateProjectWithUsers
					.calledWith(@project)
					.should.equal true
			
			it "should look up the user", ->
				@UserGetter.getUser
					.calledWith(@user_id, { isAdmin: true })
					.should.equal true
					
			it "should check the privilege level", ->
				@AuthorizationManager.getPrivilegeLevelForProject
					.calledWith(@project, @user)
					.should.equal true

			it "should return the project model view, privilege level and protocol version", ->
				@callback.calledWith(null, @projectModelView, "owner").should.equal true
				
		describe "when not authorized", ->
			beforeEach ->
				@AuthorizationManager.getPrivilegeLevelForProject =
					sinon.stub().callsArgWith(2, null, false, null)
				@EditorController.buildJoinProjectView(@project_id, @user_id, @callback)
				
			it "should return false in the callback", ->
				@callback.calledWith(null, null, false).should.equal true


	describe "leaveProject", ->
		beforeEach ->
			sinon.stub(@client, "set")
			sinon.stub(@client, "get").callsArgWith(1, null, @project_id)
			@EditorRealTimeController.emitToRoom = sinon.stub()
			@EditorController.flushProjectIfEmpty = sinon.stub()
			@EditorController.leaveProject @client, @user
			@ConnectedUsersManager.markUserAsDisconnected.callsArgWith(2)

		it "should call the flush project if empty function", ->
			@EditorController.flushProjectIfEmpty
				.calledWith(@project_id)
				.should.equal true

		it "should emit a clientDisconnect to the project room", ->
			@EditorRealTimeController.emitToRoom
				.calledWith(@project_id, "clientTracking.clientDisconnected", @client.id)
				.should.equal true

		it "should mark the user as connected with the ConnectedUsersManager", ->
			@ConnectedUsersManager.markUserAsDisconnected.calledWith(@project_id, @client.id).should.equal true


	describe "joinDoc", ->
		beforeEach ->
			@client.join = sinon.stub()
			@client.set("user_id", @user_id)
			@fromVersion = 40
			@docLines = ["foo", "bar"]
			@ops = ["mock-op-1", "mock-op-2"]
			@version = 42
			@DocumentUpdaterHandler.getDocument = sinon.stub().callsArgWith(3, null, @docLines, @version, @ops)

		describe "with a fromVersion", ->
			beforeEach ->
				@EditorController.joinDoc @client, @project_id, @doc_id, @fromVersion, @callback

			it "should add the client to the socket.io room for the doc", ->
				@client.join.calledWith(@doc_id).should.equal true

			it "should get the document", ->
				@DocumentUpdaterHandler.getDocument
					.calledWith(@project_id, @doc_id, @fromVersion)
					.should.equal true

			it "should return the doclines and version and ops", ->
				@callback.calledWith(null, @docLines, @version, @ops).should.equal true

			it "should increment the join-doc metric", ->
				@Metrics.inc.calledWith("editor.join-doc").should.equal true

			it "should log out the request", ->
				@logger.log
					.calledWith(user_id: @user_id, project_id: @project_id, doc_id: @doc_id, "user joining doc")
					.should.equal true

		describe "without a fromVersion", ->
			beforeEach ->
				@EditorController.joinDoc @client, @project_id, @doc_id, @callback

			it "should get the document with fromVersion=-1", ->
				@DocumentUpdaterHandler.getDocument
					.calledWith(@project_id, @doc_id, -1)
					.should.equal true

			it "should return the doclines and version and ops", ->
				@callback.calledWith(null, @docLines, @version, @ops).should.equal true

	describe "leaveDoc", ->
		beforeEach ->
			@client.leave = sinon.stub()
			@client.set("user_id", @user_id)
			@EditorController.leaveDoc @client, @project_id, @doc_id, @callback

		it "should remove the client from the socket.io room for the doc", ->
			@client.leave.calledWith(@doc_id).should.equal true

		it "should increment the leave-doc metric", ->
			@Metrics.inc.calledWith("editor.leave-doc").should.equal true

		it "should log out the request", ->
			@logger.log
				.calledWith(user_id: @user_id, project_id: @project_id, doc_id: @doc_id, "user leaving doc")

				.should.equal true

	describe "flushProjectIfEmpty", ->
		beforeEach ->	
			@DocumentUpdaterHandler.flushProjectToMongoAndDelete = sinon.stub()
			@TrackChangesManager.flushProject = sinon.stub()

		describe "when a project has no more users", ->
			it "should do the flush after the config set timeout to ensure that a reconect didn't just happen", (done)->
				@rooms[@project_id] = []
				@EditorController.flushProjectIfEmpty @project_id, =>
					@DocumentUpdaterHandler.flushProjectToMongoAndDelete.calledWith(@project_id).should.equal(true)
					@TrackChangesManager.flushProject.calledWith(@project_id).should.equal true
					done()

		describe "when a project still has connected users", ->
			it "should not flush the project", (done)->
				@rooms[@project_id] = ["socket-id-1", "socket-id-2"]
				@EditorController.flushProjectIfEmpty @project_id, =>
					@DocumentUpdaterHandler.flushProjectToMongoAndDelete.calledWith(@project_id).should.equal(false)
					@TrackChangesManager.flushProject.calledWith(@project_id).should.equal false
					done()

	describe "updateClientPosition", ->
		beforeEach ->
			@EditorRealTimeController.emitToRoom = sinon.stub()
			@ConnectedUsersManager.updateUserPosition.callsArgWith(4)
			@update = {
				doc_id: @doc_id = "doc-id-123"
				row: @row = 42
				column: @column = 37
			}


		describe "with a logged in user", ->
			beforeEach ->
				@clientParams = {
					project_id: @project_id
					first_name: @first_name = "Douglas"
					last_name: @last_name = "Adams"
					email: @email = "joe@example.com"
					user_id: @user_id = "user-id-123"
				}
				@client.get = (param, callback) => callback null, @clientParams[param]
				@EditorController.updateClientPosition @client, @update

				@populatedCursorData = 
					doc_id: @doc_id,
					id: @client.id
					name: "#{@first_name} #{@last_name}"
					row: @row
					column: @column
					email: @email
					user_id: @user_id

			it "should send the update to the project room with the user's name", ->
				@EditorRealTimeController.emitToRoom.calledWith(@project_id, "clientTracking.clientUpdated", @populatedCursorData).should.equal true

			it "should send the  cursor data to the connected user manager", (done)->
				@ConnectedUsersManager.updateUserPosition.calledWith(@project_id, @client.id, {
					user_id: @user_id,
					email: @email,
					first_name: @first_name,
					last_name: @last_name
				}, {
					row: @row
					column: @column
					doc_id: @doc_id
				}).should.equal true
				done()

		describe "with an anonymous user", ->
			beforeEach ->
				@clientParams = {
					project_id: @project_id
				}
				@client.get = (param, callback) => callback null, @clientParams[param]
				@EditorController.updateClientPosition @client, @update

			it "should send the update to the project room with an anonymous name", ->
				@EditorRealTimeController.emitToRoom
					.calledWith(@project_id, "clientTracking.clientUpdated", {
						doc_id: @doc_id,
						id: @client.id
						name: "Anonymous"
						row: @row
						column: @column
					})
					.should.equal true
				
			it "should not send cursor data to the connected user manager", (done)->
				@ConnectedUsersManager.updateUserPosition.called.should.equal false
				done()

	describe "addUserToProject", ->
		beforeEach ->
			@email = "Jane.Doe@example.com"
			@priveleges = "readOnly"
			@addedUser = { _id: "added-user" }
			@ProjectEditorHandler.buildUserModelView = sinon.stub().returns(@addedUser)
			@CollaboratorsHandler.addUserToProject = sinon.stub().callsArgWith(3, null, @addedUser)
			@EditorRealTimeController.emitToRoom = sinon.stub()
			@callback = sinon.stub()

		describe "when the project can accept more collaborators", ->
			beforeEach ->
				@LimitationsManager.isCollaboratorLimitReached = sinon.stub().callsArgWith(1, null, false)

			it "should add the user to the project", (done)->
				@EditorController.addUserToProject @project_id, @email, @priveleges, =>
					@CollaboratorsHandler.addUserToProject.calledWith(@project_id, @email.toLowerCase(), @priveleges).should.equal true
					done()

			it "should emit a userAddedToProject event", (done)->
				@EditorController.addUserToProject @project_id, @email, @priveleges, =>
					@EditorRealTimeController.emitToRoom.calledWith(@project_id, "userAddedToProject", @addedUser).should.equal true
					done()

			it "should return the user to the callback", (done)->
				@EditorController.addUserToProject @project_id, @email, @priveleges, (err, result)=>
					result.should.equal @addedUser
					done()


		describe "when the project cannot accept more collaborators", ->
			beforeEach ->
				@LimitationsManager.isCollaboratorLimitReached = sinon.stub().callsArgWith(1, null, true)
				@EditorController.addUserToProject(@project_id, @email, @priveleges, @callback)

			it "should not add the user to the project", ->
				@CollaboratorsHandler.addUserToProject.called.should.equal false

			it "should not emit a userAddedToProject event", ->
				@EditorRealTimeController.emitToRoom.called.should.equal false

			it "should return false to the callback", ->
				@callback.calledWith(null, false).should.equal true


	describe "removeUserFromProject", ->
		beforeEach ->
			@removed_user_id = "removed-user-id"
			@CollaboratorsHandler.removeUserFromProject = sinon.stub().callsArgWith(2)
			@EditorRealTimeController.emitToRoom = sinon.stub()

			@EditorController.removeUserFromProject(@project_id, @removed_user_id)

		it "remove the user from the project", ->
			@CollaboratorsHandler.removeUserFromProject
				.calledWith(@project_id, @removed_user_id)
				.should.equal true

		it "should emit a userRemovedFromProject event", ->
			@EditorRealTimeController.emitToRoom.calledWith(@project_id, "userRemovedFromProject", @removed_user_id).should.equal true

	describe "updating compiler used for project", ->
		it "should send the new compiler and project id to the project options handler", (done)->
			compiler = "latex"
			@EditorRealTimeController.emitToRoom = sinon.stub()
			@EditorController.setCompiler @project_id, compiler, (err) =>
				@ProjectOptionsHandler.setCompiler.calledWith(@project_id, compiler).should.equal true
				@EditorRealTimeController.emitToRoom.calledWith(@project_id, "compilerUpdated", compiler).should.equal true
				done()
			@ProjectOptionsHandler.setCompiler.args[0][2]()


	describe "updating language code used for project", ->
		it "should send the new languageCode and project id to the project options handler", (done)->
			languageCode = "fr"
			@EditorRealTimeController.emitToRoom = sinon.stub()
			@EditorController.setSpellCheckLanguage @project_id, languageCode, (err) =>
				@ProjectOptionsHandler.setSpellCheckLanguage.calledWith(@project_id, languageCode).should.equal true
				@EditorRealTimeController.emitToRoom.calledWith(@project_id, "spellCheckLanguageUpdated", languageCode).should.equal true
				done()
			@ProjectOptionsHandler.setSpellCheckLanguage.args[0][2]()


	describe 'setDoc', ->
		beforeEach ->
			@docLines = ["foo", "bar"]
			@DocumentUpdaterHandler.flushDocToMongo = sinon.stub().callsArg(2)
			@DocumentUpdaterHandler.setDocument = sinon.stub().callsArg(4)

		it 'should send the document to the documentUpdaterHandler', (done)->
			@DocumentUpdaterHandler.setDocument = sinon.stub().withArgs(@project_id, @doc_id, @docLines, @source).callsArg(4)
			@EditorController.setDoc @project_id, @doc_id, @docLines, @source, (err)->
				done()

		it 'should send the new doc lines to the doucment updater', (done)->
			@DocumentUpdaterHandler.setDocument = ->
			mock = sinon.mock(@DocumentUpdaterHandler).expects("setDocument").withArgs(@project_id, @doc_id, @docLines, @source).once().callsArg(4)

			@EditorController.setDoc @project_id, @doc_id, @docLines, @source, (err)=>
				mock.verify()
				done()

		it 'should flush the doc to mongo', (done)->
			@EditorController.setDoc @project_id, @doc_id, @docLines, @source, (err)=>
				@DocumentUpdaterHandler.flushDocToMongo.calledWith(@project_id, @doc_id).should.equal true
				done()


	describe 'addDocWithoutLock', ->
		beforeEach ->
			@ProjectEntityHandler.addDoc = ()->
			@EditorRealTimeController.emitToRoom = sinon.stub()
			@project_id = "12dsankj"
			@folder_id = "213kjd"
			@doc = {_id:"123ds"}
			@folder_id = "123ksajdn"
			@docName = "doc.tex"
			@docLines = ["1234","dskl"]

		it 'should add the doc using the project entity handler', (done)->
			mock = sinon.mock(@ProjectEntityHandler).expects("addDoc").withArgs(@project_id, @folder_id, @docName, @docLines).callsArg(4)

			@EditorController.addDocWithoutLock @project_id, @folder_id, @docName, @docLines, @source, ->
				mock.verify()
				done()

		it 'should send the update out to the users in the project', (done)->
			@ProjectEntityHandler.addDoc = sinon.stub().callsArgWith(4, null, @doc, @folder_id)

			@EditorController.addDocWithoutLock @project_id, @folder_id, @docName, @docLines, @source, =>
				@EditorRealTimeController.emitToRoom
					.calledWith(@project_id, "reciveNewDoc", @folder_id, @doc, @source)
					.should.equal true
				done()

		it 'should return the doc to the callback', (done) ->
			@ProjectEntityHandler.addDoc = sinon.stub().callsArgWith(4, null, @doc, @folder_id)
			@EditorController.addDocWithoutLock @project_id, @folder_id, @docName, @docLines, @source, (error, doc) =>
				doc.should.equal @doc
				done()

	describe "addDoc", ->

		beforeEach ->
			@LockManager.getLock.callsArgWith(1)
			@LockManager.releaseLock.callsArgWith(1)
			@EditorController.addDocWithoutLock = sinon.stub().callsArgWith(5)

		it "should call addDocWithoutLock", (done)->
			@EditorController.addDoc @project_id, @folder_id, @docName, @docLines, @source, =>
				@EditorController.addDocWithoutLock.calledWith(@project_id, @folder_id, @docName, @docLines, @source).should.equal true
				done()

		it "should take the lock", (done)->
			@EditorController.addDoc @project_id, @folder_id, @docName, @docLines, @source, =>
				@LockManager.getLock.calledWith(@project_id).should.equal true
				done()

		it "should release the lock", (done)->
			@EditorController.addDoc @project_id, @folder_id, @docName, @docLines, @source, =>
				@LockManager.releaseLock.calledWith(@project_id).should.equal true
				done()

		it "should error if it can't cat the lock", (done)->
			@LockManager.getLock = sinon.stub().callsArgWith(1, "timed out")
			@EditorController.addDoc @project_id, @folder_id, @docName, @docLines, @source, (err)=>
				expect(err).to.exist
				err.should.equal "timed out"
				done()			




	describe 'addFileWithoutLock:', ->
		beforeEach ->
			@ProjectEntityHandler.addFile = ->
			@EditorRealTimeController.emitToRoom = sinon.stub()
			@project_id = "12dsankj"
			@folder_id = "213kjd"
			@fileName = "file.png"
			@folder_id = "123ksajdn"
			@file = {_id:"dasdkjk"}
			@stream = new ArrayBuffer()

		it 'should add the folder using the project entity handler', (done)->
			@ProjectEntityHandler.addFile = sinon.stub().callsArgWith(4)
			@EditorController.addFileWithoutLock @project_id, @folder_id, @fileName, @stream, @source, =>
				@ProjectEntityHandler.addFile.calledWith(@project_id, @folder_id).should.equal true
				done()

		it 'should send the update of a new folder out to the users in the project', (done)->
			@ProjectEntityHandler.addFile = sinon.stub().callsArgWith(4, null, @file, @folder_id)

			@EditorController.addFileWithoutLock @project_id, @folder_id, @fileName, @stream, @source, =>
				@EditorRealTimeController.emitToRoom
					.calledWith(@project_id, "reciveNewFile", @folder_id, @file, @source)
					.should.equal true
				done()

		it "should return the file in the callback", (done) ->
			@ProjectEntityHandler.addFile = sinon.stub().callsArgWith(4, null, @file, @folder_id)
			@EditorController.addFileWithoutLock @project_id, @folder_id, @fileName, @stream, @source, (error, file) =>
				file.should.equal @file
				done()


	describe "addFile", ->

		beforeEach ->
			@LockManager.getLock.callsArgWith(1)
			@LockManager.releaseLock.callsArgWith(1)
			@EditorController.addFileWithoutLock = sinon.stub().callsArgWith(5)

		it "should call addFileWithoutLock", (done)->
			@EditorController.addFile @project_id, @folder_id, @fileName, @stream, @source, (error, file) =>
				@EditorController.addFileWithoutLock.calledWith(@project_id, @folder_id, @fileName, @stream, @source).should.equal true
				done()

		it "should take the lock", (done)->
			@EditorController.addFile @project_id, @folder_id, @fileName, @stream, @source, (error, file) =>
				@LockManager.getLock.calledWith(@project_id).should.equal true
				done()

		it "should release the lock", (done)->
			@EditorController.addFile @project_id, @folder_id, @fileName, @stream, @source, (error, file) =>
				@LockManager.releaseLock.calledWith(@project_id).should.equal true
				done()

		it "should error if it can't cat the lock", (done)->
			@LockManager.getLock = sinon.stub().callsArgWith(1, "timed out")
			@EditorController.addFile @project_id, @folder_id, @fileName, @stream, @source, (err, file) =>
				expect(err).to.exist
				err.should.equal "timed out"
				done()			




	describe "replaceFile", ->
		beforeEach ->
			@project_id = "12dsankj"
			@file_id = "file_id_here"
			@fsPath = "/folder/file.png"

		it 'should send the replace file message to the editor controller', (done)->
			@ProjectEntityHandler.replaceFile = sinon.stub().callsArgWith(3)
			@EditorController.replaceFile @project_id, @file_id, @fsPath, @source, =>
				@ProjectEntityHandler.replaceFile.calledWith(@project_id, @file_id, @fsPath).should.equal true
				done()

	describe 'addFolderWithoutLock :', ->
		beforeEach ->
			@ProjectEntityHandler.addFolder = ->
			@EditorRealTimeController.emitToRoom = sinon.stub()
			@project_id = "12dsankj"
			@folder_id = "213kjd"
			@folderName = "folder"
			@folder = {_id:"123ds"}

		it 'should add the folder using the project entity handler', (done)->
			mock = sinon.mock(@ProjectEntityHandler).expects("addFolder").withArgs(@project_id, @folder_id, @folderName).callsArg(3)

			@EditorController.addFolderWithoutLock @project_id, @folder_id, @folderName, @source, ->
				mock.verify()
				done()

		it 'should notifyProjectUsersOfNewFolder', (done)->
			@ProjectEntityHandler.addFolder = (project_id, folder_id, folderName, callback)=> callback(null, @folder, @folder_id)
			mock = sinon.mock(@EditorController.p).expects('notifyProjectUsersOfNewFolder').withArgs(@project_id, @folder_id, @folder).callsArg(3)

			@EditorController.addFolderWithoutLock @project_id, @folder_id, @folderName, @source, ->
				mock.verify()
				done()

		it 'notifyProjectUsersOfNewFolder should send update out to all users', (done)->
			@EditorController.p.notifyProjectUsersOfNewFolder @project_id, @folder_id, @folder, =>
				@EditorRealTimeController.emitToRoom
					.calledWith(@project_id, "reciveNewFolder", @folder_id, @folder)
					.should.equal true
				done()
	
		it 'should return the folder in the callback', (done) ->
			@ProjectEntityHandler.addFolder = (project_id, folder_id, folderName, callback)=> callback(null, @folder, @folder_id)
			@EditorController.addFolderWithoutLock @project_id, @folder_id, @folderName, @source, (error, folder) =>
				folder.should.equal @folder
				done()


	describe "addFolder", ->

		beforeEach ->
			@LockManager.getLock.callsArgWith(1)
			@LockManager.releaseLock.callsArgWith(1)
			@EditorController.addFolderWithoutLock = sinon.stub().callsArgWith(4)

		it "should call addFolderWithoutLock", (done)->
			@EditorController.addFolder @project_id, @folder_id, @folderName, @source, (error, file) =>
				@EditorController.addFolderWithoutLock.calledWith(@project_id, @folder_id, @folderName, @source).should.equal true
				done()

		it "should take the lock", (done)->
			@EditorController.addFolder @project_id, @folder_id, @folderName, @source, (error, file) =>
				@LockManager.getLock.calledWith(@project_id).should.equal true
				done()

		it "should release the lock", (done)->
			@EditorController.addFolder @project_id, @folder_id, @folderName, @source, (error, file) =>
				@LockManager.releaseLock.calledWith(@project_id).should.equal true
				done()

		it "should error if it can't cat the lock", (done)->
			@LockManager.getLock = sinon.stub().callsArgWith(1, "timed out")
			@EditorController.addFolder @project_id, @folder_id, @folderName, @source, (err, file) =>
				expect(err).to.exist
				err.should.equal "timed out"
				done()			


	describe 'mkdirpWithoutLock :', ->

		it 'should make the dirs and notifyProjectUsersOfNewFolder', (done)->
			path = "folder1/folder2"
			@folder1 = {_id:"folder_1_id_here"}
			@folder2 = {_id:"folder_2_id_here", parentFolder_id:@folder1._id}
			@folder3 = {_id:"folder_3_id_here", parentFolder_id:@folder2._id}

			@ProjectEntityHandler.mkdirp = sinon.stub().withArgs(@project_id, path).callsArgWith(2, null, [@folder1, @folder2, @folder3], @folder3)

			@EditorController.p.notifyProjectUsersOfNewFolder = sinon.stub().callsArg(3)

			@EditorController.mkdirpWithoutLock @project_id, path, (err, newFolders, lastFolder)=>
				@EditorController.p.notifyProjectUsersOfNewFolder.calledWith(@project_id, @folder1._id, @folder2).should.equal true
				@EditorController.p.notifyProjectUsersOfNewFolder.calledWith(@project_id, @folder2._id, @folder3).should.equal true
				newFolders.should.deep.equal [@folder1, @folder2, @folder3]
				lastFolder.should.equal @folder3
				done()


	describe "mkdirp", ->

		beforeEach ->
			@path = "folder1/folder2"
			@LockManager.getLock.callsArgWith(1)
			@LockManager.releaseLock.callsArgWith(1)
			@EditorController.mkdirpWithoutLock = sinon.stub().callsArgWith(2)

		it "should call mkdirpWithoutLock", (done)->
			@EditorController.mkdirp @project_id, @path, (error, file) =>
				@EditorController.mkdirpWithoutLock.calledWith(@project_id, @path).should.equal true
				done()

		it "should take the lock", (done)->
			@EditorController.mkdirp @project_id, @path, (error, file) =>
				@LockManager.getLock.calledWith(@project_id).should.equal true
				done()

		it "should release the lock", (done)->
			@EditorController.mkdirp @project_id, @path, (error, file) =>
				@LockManager.releaseLock.calledWith(@project_id).should.equal true
				done()

		it "should error if it can't cat the lock", (done)->
			@LockManager.getLock = sinon.stub().callsArgWith(1, "timed out")
			@EditorController.mkdirp @project_id, @path, (err, file) =>
				expect(err).to.exist
				err.should.equal "timed out"
				done()			


	describe "deleteEntity", ->

		beforeEach ->
			@LockManager.getLock.callsArgWith(1)
			@LockManager.releaseLock.callsArgWith(1)
			@EditorController.deleteEntityWithoutLock = sinon.stub().callsArgWith(4)

		it "should call deleteEntityWithoutLock", (done)->
			@EditorController.deleteEntity @project_id, @entity_id, @type, @source,  =>
				@EditorController.deleteEntityWithoutLock.calledWith(@project_id, @entity_id, @type, @source).should.equal true
				done()

		it "should take the lock", (done)->
			@EditorController.deleteEntity @project_id, @entity_id, @type, @source,  =>
				@LockManager.getLock.calledWith(@project_id).should.equal true
				done()

		it "should release the lock", (done)->
			@EditorController.deleteEntity @project_id, @entity_id, @type, @source, (error)=>
				@LockManager.releaseLock.calledWith(@project_id).should.equal true
				done()

		it "should error if it can't cat the lock", (done)->
			@LockManager.getLock = sinon.stub().callsArgWith(1, "timed out")
			@EditorController.deleteEntity @project_id, @entity_id, @type, @source, (err)=>
				expect(err).to.exist
				err.should.equal "timed out"
				done()			



	describe 'deleteEntityWithoutLock', ->
		beforeEach ->
			@ProjectEntityHandler.deleteEntity = (project_id, entity_id, type, callback)-> callback()
			@entity_id = "entity_id_here"
			@type = "doc"
			@EditorRealTimeController.emitToRoom = sinon.stub()

		it 'should delete the folder using the project entity handler', (done)->
			mock = sinon.mock(@ProjectEntityHandler).expects("deleteEntity").withArgs(@project_id, @entity_id, @type).callsArg(3)

			@EditorController.deleteEntityWithoutLock @project_id, @entity_id, @type, @source, ->
				mock.verify()
				done()

		it 'notify users an entity has been deleted', (done)->
			@EditorController.deleteEntityWithoutLock @project_id, @entity_id, @type, @source, =>
				@EditorRealTimeController.emitToRoom
					.calledWith(@project_id, "removeEntity", @entity_id, @source)
					.should.equal true
				done()

	describe "getting a list of project paths", ->

		it 'should call the project entity handler to get an array of docs', (done)->
			fullDocsHash = 
				"/doc1.tex":{lines:["das"], _id:"1234"}
				"/doc2.tex":{lines:["dshajkh"]}
			project_id = "d312nkjnajn"
			@ProjectEntityHandler.getAllDocs = sinon.stub().callsArgWith(1, null, fullDocsHash)
			@EditorController.getListOfDocPaths project_id, (err, returnedDocs)->
				returnedDocs.length.should.equal 2
				returnedDocs[0]._id.should.equal "1234"
				assert.equal returnedDocs[0].lines, undefined
				returnedDocs[1].path.should.equal "doc2.tex"	
				done()

	describe "forceResyncOfDropbox", ->
		it 'should tell the project entity handler to flush to tpds', (done)->
			@ProjectEntityHandler.flushProjectToThirdPartyDataStore = sinon.stub().callsArgWith(1)
			@EditorController.forceResyncOfDropbox @project_id, (err)=>
				@ProjectEntityHandler.flushProjectToThirdPartyDataStore.calledWith(@project_id).should.equal true
				done()

	describe "notifyUsersProjectHasBeenDeletedOrRenamed", ->
		it 'should emmit a message to all users in a project', (done)->
			@EditorRealTimeController.emitToRoom = sinon.stub()
			@EditorController.notifyUsersProjectHasBeenDeletedOrRenamed @project_id, (err)=>
				@EditorRealTimeController.emitToRoom
					.calledWith(@project_id, "projectRenamedOrDeletedByExternalSource")
					.should.equal true
				done()

	describe "updateProjectDescription", ->
		beforeEach ->
			@description = "new description"
			@EditorRealTimeController.emitToRoom = sinon.stub()


		it "should send the new description to the project details handler", (done)->
			@ProjectDetailsHandler.setProjectDescription.callsArgWith(2)
			@EditorController.updateProjectDescription @project_id, @description, =>
				@ProjectDetailsHandler.setProjectDescription.calledWith(@project_id, @description).should.equal true
				done()

		it "should notify the other clients about the updated description", (done)->
			@ProjectDetailsHandler.setProjectDescription.callsArgWith(2)
			@EditorController.updateProjectDescription @project_id, @description, =>
				@EditorRealTimeController.emitToRoom.calledWith(@project_id, "projectDescriptionUpdated", @description).should.equal true				
				done()


	describe "deleteProject", ->

		beforeEach ->
			@err = "errro"
			@ProjectDeleter.deleteProject = sinon.stub().callsArgWith(1, @err)

		it "should call the project handler", (done)->
			@EditorController.deleteProject @project_id, (err)=>
				err.should.equal @err
				@ProjectDeleter.deleteProject.calledWith(@project_id).should.equal true
				done()


	describe "renameEntity", ->

		beforeEach ->
			@err = "errro"
			@entity_id = "entity_id_here"
			@entityType = "doc"
			@newName = "bobsfile.tex"
			@ProjectEntityHandler.renameEntity = sinon.stub().callsArgWith(4, @err)
			@EditorRealTimeController.emitToRoom = sinon.stub()

		it "should call the project handler", (done)->
			@EditorController.renameEntity @project_id, @entity_id, @entityType, @newName, =>
				@ProjectEntityHandler.renameEntity.calledWith(@project_id, @entity_id, @entityType, @newName).should.equal true
				done()


		it "should emit the update to the room", (done)->
			@EditorController.renameEntity @project_id, @entity_id, @entityType, @newName, =>
				@EditorRealTimeController.emitToRoom.calledWith(@project_id, 'reciveEntityRename', @entity_id, @newName).should.equal true				
				done()

	describe "moveEntity", ->

		beforeEach ->
			@err = "errro"
			@entity_id = "entity_id_here"
			@entityType = "doc"
			@folder_id = "313dasd21dasdsa"
			@ProjectEntityHandler.moveEntity = sinon.stub().callsArgWith(4, @err)
			@EditorRealTimeController.emitToRoom = sinon.stub()

		it "should call the ProjectEntityHandler", (done)->
			@EditorController.moveEntity @project_id, @entity_id, @folder_id, @entityType, =>
				@ProjectEntityHandler.moveEntity.calledWith(@project_id, @entity_id, @folder_id, @entityType).should.equal true
				done()


		it "should emit the update to the room", (done)->
			@EditorController.moveEntity @project_id, @entity_id, @folder_id, @entityType, =>
				@EditorRealTimeController.emitToRoom.calledWith(@project_id, 'reciveEntityMove', @entity_id, @folder_id).should.equal true				
				done()

	describe "renameProject", ->

		beforeEach ->
			@err = "errro"
			@window_id = "kdsjklj290jlk"
			@newName = "new name here"
			@ProjectDetailsHandler.renameProject = sinon.stub().callsArgWith(2, @err)
			@EditorRealTimeController.emitToRoom = sinon.stub()

		it "should call the EditorController", (done)->
			@EditorController.renameProject @project_id, @newName, =>
				@ProjectDetailsHandler.renameProject.calledWith(@project_id, @newName).should.equal true
				done()


		it "should emit the update to the room", (done)->
			@EditorController.renameProject @project_id, @newName, =>
				@EditorRealTimeController.emitToRoom.calledWith(@project_id, 'projectNameUpdated', @newName).should.equal true				
				done()


	describe "setPublicAccessLevel", ->

		beforeEach ->
			@newAccessLevel = "public"
			@ProjectDetailsHandler.setPublicAccessLevel = sinon.stub().callsArgWith(2, null)
			@EditorRealTimeController.emitToRoom = sinon.stub()

		it "should call the EditorController", (done)->
			@EditorController.setPublicAccessLevel @project_id, @newAccessLevel, =>
				@ProjectDetailsHandler.setPublicAccessLevel.calledWith(@project_id, @newAccessLevel).should.equal true
				done()

		it "should emit the update to the room", (done)->
			@EditorController.setPublicAccessLevel @project_id, @newAccessLevel, =>
				@EditorRealTimeController.emitToRoom.calledWith(@project_id, 'publicAccessLevelUpdated', @newAccessLevel).should.equal true				
				done()

	describe "setRootDoc", ->

		beforeEach ->
			@newRootDocID = "21312321321"
			@ProjectEntityHandler.setRootDoc = sinon.stub().callsArgWith(2, null)
			@EditorRealTimeController.emitToRoom = sinon.stub()

		it "should call the ProjectEntityHandler", (done)->
			@EditorController.setRootDoc @project_id, @newRootDocID, =>
				@ProjectEntityHandler.setRootDoc.calledWith(@project_id, @newRootDocID).should.equal true
				done()

		it "should emit the update to the room", (done)->
			@EditorController.setRootDoc @project_id, @newRootDocID, =>
				@EditorRealTimeController.emitToRoom.calledWith(@project_id, 'rootDocUpdated', @newRootDocID).should.equal true				
				done()