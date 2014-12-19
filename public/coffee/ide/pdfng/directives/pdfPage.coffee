define [
	"base"
], (App) ->
	# App = angular.module 'pdfPage', ['pdfHighlights']

	App.directive 'pdfPage', ['$timeout', 'pdfHighlights', ($timeout, pdfHighlights) ->
		{
			require: '^pdfViewer',
			template: '''
			<div class="plv-page-view page-view">
				<div class="pdf-canvas pdfng-empty"></div>
				<div class="plv-text-layer text-layer"></div>
				<div class="plv-annotations-layer annotations-layer"></div>
				<div class="plv-highlights-layer highlights-layer"></div>
			</div>
			'''
			link: (scope, element, attrs, ctrl) ->
				canvasElement = $(element).find('.pdf-canvas')
				textElement = $(element).find('.text-layer')
				annotationsElement = $(element).find('.annotations-layer')
				highlightsElement = $(element).find('.highlights-layer')

				updatePageSize = (size) ->
					h = Math.floor(size[0])
					w = Math.floor(size[1])
					element.height(h)
					element.width(w)
					canvasElement.height(h)
					canvasElement.width(w)
					scope.page.sized = true

				isVisible = (containerSize) ->
					elemTop = element.offset().top - containerSize[2]
					elemBottom = elemTop + element.innerHeight()
					visible = (elemTop < containerSize[1] and elemBottom > 0)
					scope.page.visible = visible
					scope.page.elemTop = elemTop
					scope.page.elemBottom = elemBottom
					return visible

				renderPage = () ->
					scope.document.renderPage {
						canvas: canvasElement,
						text: textElement
						annotations: annotationsElement
						highlights: highlightsElement
					}, scope.page.pageNum

				pausePage = () ->
					scope.document.pause {
						canvas: canvasElement,
						text: textElement
					}, scope.page.pageNum

				# keep track of our page element, so we can access it in the
				# parent with scope.pages[i].element
				scope.page.element = element

				if (!scope.page.sized && scope.defaultPageSize)
					updatePageSize scope.defaultPageSize

				if scope.page.current
						# console.log 'we must scroll to this page', scope.page.pageNum, 'at position', scope.page.position
						renderPage()
						# this is the current page, we want to scroll it into view
						ctrl.setPdfPosition(scope.page, scope.page.position)

				scope.$watch 'defaultPageSize', (defaultPageSize) ->
					return unless defaultPageSize?
					updatePageSize defaultPageSize

				watchHandle = scope.$watch 'containerSize', (containerSize, oldVal) ->
					return unless containerSize?
					return unless scope.page.sized
					oldVisible = scope.page.visible
					newVisible = isVisible containerSize
					scope.page.visible = newVisible
					if newVisible && !oldVisible
						renderPage()
						# TODO deregister this listener after the page is rendered
						#watchHandle()
					else if !newVisible && oldVisible
						pausePage()

				element.on 'dblclick', (e) ->
					offset = $(element).find('.pdf-canvas').offset()
					dx = e.pageX - offset.left
					dy = e.pageY - offset.top
					scope.document.getPdfViewport(scope.page.pageNum).then (viewport) ->
						pdfPoint = viewport.convertToPdfPoint(dx, dy);
						event = {
							page: scope.page.pageNum
							x: pdfPoint[0],
							y: viewport.viewBox[3] - pdfPoint[1]
						}
						scope.$emit 'pdfDoubleClick', event

				highlightsLayer = new pdfHighlights({
					highlights: highlightsElement
				})

				scope.$watch 'highlights', (highlights, oldVal) ->
					return unless highlights?
					return unless highlights.length > 0
					if scope.timeoutHandler
						$timeout.cancel(scope.timeoutHandler)
						highlightsLayer.clearHighlights()
						scope.timeoutHandler

					# console.log 'got highlight watch in pdfPage', scope.page
					pageHighlights = (h for h in highlights when h.page == scope.page.pageNum)
					return unless pageHighlights.length
					scope.document.getPdfViewport(scope.page.pageNum).then (viewport) ->
						for hl in pageHighlights
							# console.log 'adding highlight', h, viewport
							top = viewport.viewBox[3] - hl.v
							highlightsLayer.addHighlight viewport, hl.h, top, hl.width, hl.height
					scope.timeoutHandler = $timeout () ->
						highlightsLayer.clearHighlights()
						scope.timeoutHandler = null
					, 1000

				scope.$on "$destroy", () ->
					if scope.timeoutHandler?
						$timeout.cancel(scope.timeoutHandler)
						highlightsLayer.clearHighlights()

		}
	]
