_ = require('underscore')

PersonalEmailLayout = require("./Layouts/PersonalEmailLayout")
NotificationEmailLayout = require("./Layouts/NotificationEmailLayout")

templates = {}

templates.welcome =	
	subject:  _.template "Welcome to ShareLaTeX"
	layout: PersonalEmailLayout
	type:"lifecycle"
	compiledTemplate: _.template '''
Hi <%= first_name %>, thanks for signing up to ShareLaTeX. If you ever get lost, you can log in again <a href="https://www.sharelatex.com/login">here</a>.
<p>
I’m the co-founder of ShareLaTeX and I love talking to our users about our service. Please feel free to get in touch by replying to this email and I will get back to you within a day.

<p>

Regards, <br>
Henry <br>
ShareLaTeX Co-founder
'''

templates.canceledSubscription = 
	subject:  _.template "ShareLaTeX thoughts"
	layout: PersonalEmailLayout
	type:"lifecycle"
	compiledTemplate: _.template '''
Hi <%= first_name %>,

I am sorry to see you cancelled your premium account. I wondered if you would mind giving me some advice on what the site is lacking at the moment? Criticism from our users about what is missing is the best thing for us to help improve the tool. 

Thank you in advance. 

<p>
Henry <br>
ShareLaTeX Co-founder
'''

templates.passwordReset =	
	subject:  _.template "Password Reset - ShareLatex.com"
	layout: NotificationEmailLayout
	type:"notification"
	compiledTemplate: _.template '''
<h1 class="h1">Password Reset</h1>
<p>
Your password has been reset, the new password is <p> <%= newPassword %>
<p>
please <a href="<%= siteUrl %>/login">login here</a> and then change your password <a href="<%= siteUrl %>/user/settings"> in your user settings</a>
'''

templates.projectSharedWithYou = 
	subject: _.template "<%= owner.email %> wants to share <%= project.name %> with you"
	layout: NotificationEmailLayout
	type:"notification"
	compiledTemplate: _.template '''
<h1 class="h1"><%= owner.email %> wants to share <a href="<%= project.url %>">'<%= project.name %>'</a> with you</h1>
<p>&nbsp;</p>
<center>
	<div style="width:200px;background-color:#0069CC;border:1px solid #02A9D6;border-radius:4px;padding:15px; margin:10px 5px">
		<div style="padding-right:10px;padding-left:10px">
			<a href="<%= project.url %>" style="text-decoration:none" target="_blank">
				<span style= "font-size:16px;font-family:Arial;font-weight:bold;color:#fff;white-space:nowrap;display:block; text-align:center">
		  			View Project
				</span>
			</a>
		</div>
	</div>
</center>
'''

module.exports =

	buildEmail: (templateName, opts)->
		template = templates[templateName]
		opts.body = template.compiledTemplate(opts)
		return {
			subject : template.subject(opts)
			html: template.layout(opts)
			type:template.type
		}

