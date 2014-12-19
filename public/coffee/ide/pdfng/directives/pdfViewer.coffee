define [
	"base"
	"ide/pdfng/directives/pdfTextLayer"
	"ide/pdfng/directives/pdfAnnotations"
	"ide/pdfng/directives/pdfHighlights"
	"ide/pdfng/directives/pdfRenderer"
	"ide/pdfng/directives/pdfPage"
	"ide/pdfng/directives/pdfSpinner"
	"libs/pdf"  # needs pdfjs-1.0.712, override the path in require.js to get it
], (
	App
	pdfTextLayer
	pdfAnnotations
	pdfHighlights
	pdfRenderer
	pdfPage
	pdfSpinner
	pdf
) ->

	# App = angular.module 'pdfViewerApp', ['pdfPage', 'PDFRenderer', 'pdfHighlights']

	App.controller 'pdfViewerController', ['$scope', '$q', '$timeout', 'PDFRenderer', '$element', 'pdfHighlights', 'pdfSpinner', ($scope, $q, $timeout, PDFRenderer, $element, pdfHighlights, pdfSpinner) ->
		@load = () ->
			# $scope.pages = []

			$scope.document.destroy() if $scope.document?

			# TODO need a proper url manipulation library to add to query string
			$scope.document = new PDFRenderer($scope.pdfSrc + '&pdfng=true' , {
				scale: 1,
				navigateFn: (ref) ->
					# this function captures clicks on the annotation links
					$scope.navigateTo = ref
					$scope.$apply()
				progressCallback: (progress) ->
					$scope.$emit 'progress', progress
			})

			# we will have all the main information needed to start display
			# after the following promise is resolved
			$scope.loaded = $q.all({
				numPages: $scope.document.getNumPages()
				# get size of first page as default @ scale 1
				pdfViewport: $scope.document.getPdfViewport 1, 1
				}).then (result) ->
					$scope.pdfViewport = result.pdfViewport
					$scope.pdfPageSize = [
						result.pdfViewport.height,
						result.pdfViewport.width
					]
					# console.log 'resolved q.all, page size is', result
					$scope.numPages = result.numPages
					$scope.$emit "loaded"

		@setScale = (scale, containerHeight, containerWidth) ->
			$scope.loaded.then () ->
				scale = {} if not scale?
				if containerHeight == 0 or containerWidth == 0
					numScale = 1
				else if scale.scaleMode == 'scale_mode_fit_width'
					# TODO make this dynamic
					numScale = (containerWidth - 40) / ($scope.pdfPageSize[1])
				else if scale.scaleMode == 'scale_mode_fit_height'
					# TODO magic numbers for jquery ui layout
					numScale = (containerHeight - 20) / ($scope.pdfPageSize[0])
				else if scale.scaleMode == 'scale_mode_value'
					numScale = scale.scale
				else if scale.scaleMode == 'scale_mode_auto'
					# TODO
				else
					scale.scaleMode = 'scale_mode_fit_width'
					numScale = (containerWidth - 40) / ($scope.pdfPageSize[1])
					# TODO
				$scope.scale.scale = numScale
				$scope.document.setScale(numScale)
				$scope.defaultPageSize = [
					numScale * $scope.pdfPageSize[0],
					numScale * $scope.pdfPageSize[1]
				]
				# console.log 'in setScale result', $scope.scale.scale, $scope.defaultPageSize

		@redraw = (position) ->
			# console.log 'in redraw'
			# console.log 'reseting pages array for', $scope.numPages
			$scope.pages = ({
				pageNum: i + 1
			} for i in [0 .. $scope.numPages-1])
			if position? && position.page?
				# console.log 'position is', position.page, position.offset
				# console.log 'setting current page', position.page
				pagenum = position.page
				$scope.pages[pagenum].current = true
				$scope.pages[pagenum].position = position

		@zoomIn = () ->
			# console.log 'zoom in'
			newScale = $scope.scale.scale * 1.2
			$scope.forceScale = { scaleMode: 'scale_mode_value', scale: newScale }

		@zoomOut = () ->
			# console.log 'zoom out'
			newScale = $scope.scale.scale / 1.2
			$scope.forceScale = { scaleMode: 'scale_mode_value', scale: newScale }

		@fitWidth = () ->
			# console.log 'fit width'
			$scope.forceScale = { scaleMode: 'scale_mode_fit_width' }

		@fitHeight = () ->
			# console.log 'fit height'
			$scope.forceScale = { scaleMode: 'scale_mode_fit_height' }

		@checkPosition = () ->
			# console.log 'check position'
			$scope.forceCheck = ($scope.forceCheck || 0) + 1

		@showRandomHighlights = () ->
			# console.log 'show highlights'
			$scope.highlights = [
				{
					page: 3
					h: 100
					v: 100
					height: 30
					width: 200
				}
			]

		# we work with (pagenumber, % of height down page from top)
		# pdfListView works with (pagenumber, vertical position up page from
		# bottom measured in pts)

		@getPdfPosition = () ->
			# console.log 'in getPdfPosition'
			topPageIdx = 0
			topPage = $scope.pages[0]
			# find first visible page
			visible = $scope.pages.some (page, i) ->
				[topPageIdx, topPage] = [i, page] if page.visible
			if visible
				# console.log 'found it', topPageIdx
			else
				# console.log 'CANNOT FIND TOP PAGE'
				return

			# console.log 'top page is', topPage.pageNum, topPage.elemTop, topPage.elemBottom, topPage
			top = topPage.elemTop
			bottom = topPage.elemBottom
			viewportTop = 0
			viewportHeight = $element.height()
			topVisible = (top >= viewportTop && top < viewportTop + viewportHeight)
			someContentVisible = (top < viewportTop && bottom > viewportTop)
			# console.log 'in PdfListView', top, topVisible, someContentVisible, viewportTop
			if topVisible
				canvasOffset = 0
			else if someContentVisible
				canvasOffset = viewportTop - top
			else
				canvasOffset = null
			# console.log 'pdfListview position = ', canvasOffset
			# instead of using promise, check if size is known and revert to
			# default otherwise
			# console.log 'looking up viewport', topPage.viewport, $scope.pdfViewport
			if topPage.viewport
				viewport = topPage.viewport
				pdfOffset = viewport.convertToPdfPoint(0, canvasOffset);
			else
				# console.log 'WARNING: had to default to global page size'
				viewport = $scope.pdfViewport
				scaledOffset = canvasOffset / $scope.scale.scale
				pdfOffset = viewport.convertToPdfPoint(0, scaledOffset);
			# console.log 'converted to offset = ', pdfOffset
			newPosition = {
				"page": topPageIdx,
				"offset" : { "top" : pdfOffset[1], "left": 0	}
			}
			return newPosition

		@computeOffset = (page, position) ->
			# console.log 'computing offset for', page, position
			element = page.element
			#console.log 'element =', $(element), 'parent =', $(element).parent()
			t1 = $(element).offset()?.top
			t2 = $(element).parent().offset()?.top
			if not (t1? and t2?)
				return $q((resolve, reject) -> reject('elements destroyed'))
			pageTop = $(element).offset().top - $(element).parent().offset().top
			# console.log('top of page scroll is', pageTop, 'vs', page.elemTop)
			# console.log('inner height is', $(element).innerHeight())
			currentScroll = $(element).parent().scrollTop()
			offset = position.offset
			# convert offset to pixels
			return $scope.document.getPdfViewport(page.pageNum).then (viewport) ->
				page.viewport = viewport
				pageOffset = viewport.convertToViewportPoint(offset.left, offset.top)
				# console.log 'addition offset =', pageOffset
				# console.log 'total', pageTop + pageOffset[1]
				Math.round(pageTop + pageOffset[1] + currentScroll) ## 10 is margin

		@setPdfPosition = (page, position) ->
			# console.log 'required pdf Position is', position
			@computeOffset(page, position).then (offset) ->
				$scope.pleaseScrollTo =  offset
				$scope.position = position

		return this

	]

	App.directive 'pdfViewer', ['$q', '$timeout', 'pdfSpinner', ($q, $timeout, pdfSpinner) ->
		{
			controller: 'pdfViewerController'
			controllerAs: 'ctrl'
			scope: {
				"pdfSrc": "="
				"highlights": "="
				"position": "="
				"scale": "="
				"pleaseJumpTo": "="
			}
			template: """
			<div data-pdf-page class='pdf-page-container page-container' ng-repeat='page in pages'></div>
			"""
			link: (scope, element, attrs, ctrl) ->
				# console.log 'in pdfViewer element is', element
				# console.log 'attrs', attrs
				spinner = new pdfSpinner
				layoutReady = $q.defer()
				layoutReady.notify 'waiting for layout'
				layoutReady.promise.then () ->
					# console.log 'layoutReady was resolved'

				# TODO can we combine this with scope.parentSize, need to finalize boxes
				updateContainer = () ->
					scope.containerSize = [
						element.innerWidth()
						element.innerHeight()
						element.offset().top
					]

				doRescale = (scale) ->
					# console.log 'doRescale', scale
					origposition = angular.copy scope.position
					# console.log 'origposition', origposition
					layoutReady.promise.then () ->
						[h, w] = [element.innerHeight(), element.width()]
						# console.log 'in promise', h, w
						ctrl.setScale(scale, h, w).then () ->
							spinner.remove(element)
							ctrl.redraw(origposition)

				checkElementReady = () ->
					# if element is zero-sized keep checking until it is ready
					if element.height() == 0 or element.width() == 0
						$timeout () ->
							checkElementReady()
						, 250
					else
						scope.$broadcast 'layout-ready' if !scope.parentSize?

				checkElementReady()

				scope.$on 'layout-ready', () ->
					# console.log 'GOT LAYOUT READY EVENT'
					# console.log 'calling refresh'
					updateContainer()
					spinner.add(element)
					layoutReady.resolve 'layout is ready'
					scope.parentSize = [
						element.innerHeight(),
						element.innerWidth()
					]
					scope.$emit 'flash-controls'
					#scope.$apply()

				scope.$on 'layout:main:resize', () ->
					# console.log 'GOT LAYOUT-MAIN-RESIZE EVENT'
					scope.parentSize = [
						element.innerHeight(),
						element.innerWidth()
					]
					scope.$apply()


				scope.$on 'layout:pdf:resize', () ->
					# console.log 'GOT LAYOUT-PDF-RESIZE EVENT'
					scope.parentSize = [
						element.innerHeight(),
						element.innerWidth()
					]
					#scope.$apply()

				element.on 'scroll', () ->
					#console.log 'scroll event', element.scrollTop(), 'adjusting?', scope.adjustingScroll
					if scope.adjustingScroll
						updateContainer()
						scope.$apply()
						scope.adjustingScroll = false
						return
					scope.scrolled = true
					if scope.scrollHandlerTimeout
						$timeout.cancel(scope.scrollHandlerTimeout)
					scope.scrollHandlerTimeout = $timeout scrollHandler, 100

				scrollHandler = () ->
					scope.scrollHandlerTimeout = null
					updateContainer()
					scope.$apply()
					newPosition = ctrl.getPdfPosition()
					if newPosition?
						scope.position = newPosition
					scope.$apply()

				scope.$watch 'pdfSrc', (newVal, oldVal) ->
					# console.log 'loading pdf', newVal, oldVal
					return unless newVal?
					ctrl.load()
					# trigger a redraw
					scope.scale = angular.copy (scope.scale)

				scope.$watch 'scale', (newVal, oldVal) ->
					# no need to set scale when initialising, done in pdfSrc
					return if newVal == oldVal
					# console.log 'XXX calling Setscale in scale watch'
					doRescale newVal

				scope.$watch 'forceScale', (newVal, oldVal) ->
					# console.log 'got change in numscale watcher', newVal, oldVal
					return unless newVal?
					doRescale newVal

#				scope.$watch 'position', (newVal, oldVal) ->
#					console.log 'got change in position watcher', newVal, oldVal

				scope.$watch 'forceCheck', (newVal, oldVal) ->
					# console.log 'forceCheck', newVal, oldVal
					return unless newVal?
					scope.adjustingScroll = true  # temporarily disable scroll
					doRescale scope.scale

				scope.$watch('parentSize', (newVal, oldVal) ->
					# console.log 'XXX in parentSize watch', newVal, oldVal
					# if newVal == oldVal
					# 	console.log 'returning because old and new are the same'
					# 	return
					return unless oldVal?
					# console.log 'XXX calling setScale in parentSize watcher'
					doRescale scope.scale
				, true)

				# scope.$watch 'elementWidth', (newVal, oldVal) ->
				# 	console.log '*** watch INTERVAL element width is', newVal, oldVal

				scope.$watch 'pleaseScrollTo', (newVal, oldVal) ->
					# console.log 'got request to ScrollTo', newVal, 'oldVal', oldVal
					return unless newVal?
					scope.adjustingScroll = true  # temporarily disable scroll
																				# handler while we reposition
					$(element).scrollTop(newVal)
					scope.pleaseScrollTo = undefined

				scope.$watch 'pleaseJumpTo', (newPosition, oldPosition) ->
					# console.log 'in pleaseJumpTo', newPosition, oldPosition
					return unless newPosition?
					ctrl.setPdfPosition scope.pages[newPosition.page-1], newPosition

				scope.$watch 'navigateTo', (newVal, oldVal) ->
					return unless newVal?
					# console.log 'got request to navigate to', newVal, 'oldVal', oldVal
					scope.navigateTo = undefined
					# console.log 'navigate to', newVal
					# console.log 'look up page num'
					scope.document.getDestination(newVal.dest).then (r) ->
						# console.log 'need to go to', r
						# console.log 'page ref is', r[0]
						scope.document.getPageIndex(r[0]).then (pidx) ->
							# console.log 'page num is', pidx
							page = scope.pages[pidx]
							scope.document.getPdfViewport(page.pageNum).then (viewport) ->
								#console.log 'got viewport', viewport
								coords = viewport.convertToViewportPoint r[2], r[3]
								#console.log	'viewport position', coords
								#console.log 'r is', r, 'r[1]', r[1], 'r[1].name', r[1].name
								if r[1].name == 'XYZ'
									#console.log 'XYZ:', r[2], r[3]
									newPosition = {page: pidx, offset: {top: r[3], left: r[2]}}
									ctrl.setPdfPosition scope.pages[pidx], newPosition # XXX?

				scope.$watch "highlights", (areas) ->
					# console.log 'got HIGHLIGHTS in pdfViewer', areas
					return if !areas?
					#console.log 'areas are', areas
					highlights = for area in areas or []
						{
							page: area.page - 1
							highlight:
								left: area.h
								top: area.v
								height: area.height
								width: area.width
						}
					#console.log 'highlights', highlights

					return if !highlights.length

					first = highlights[0]

					pageNum = scope.pages[first.page].pageNum

					scope.document.getPdfViewport(pageNum).then (viewport) ->
						position = {
							page: first.page
							offset:
								left: first.highlight.left
								top: viewport.viewBox[3] - first.highlight.top + first.highlight.height + 72
						}
						ctrl.setPdfPosition(scope.pages[first.page], position)

				scope.$watch '$destroy', () ->
					#console.log 'handle pdfng directive destroy'


		}
	]
