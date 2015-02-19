define [
	"base"
	"libs/pdfListView/PdfListView"
	"libs/pdfListView/TextLayerBuilder"
	"libs/pdfListView/AnnotationsLayerBuilder"
	"libs/pdfListView/HighlightsLayerBuilder"
	"text!libs/pdfListView/TextLayer.css"
	"text!libs/pdfListView/AnnotationsLayer.css"
	"text!libs/pdfListView/HighlightsLayer.css"
], (
	App
	PDFListView
	TextLayerBuilder
	AnnotationsLayerBuilder
	HighlightsLayerBuilder
	textLayerCss
	annotationsLayerCss
	highlightsLayerCss
) ->
	if PDFJS?
		PDFJS.workerSrc = window.pdfJsWorkerPath

	style = $("<style/>")
	style.text(textLayerCss + "\n" + annotationsLayerCss + "\n" + highlightsLayerCss)
	$("body").append(style)

	App.directive "pdfjs", ["$timeout", "localStorage", ($timeout, localStorage) ->
		return {
			scope: {
				"pdfSrc": "="
				"highlights": "="
				"position": "="
				"dblClickCallback": "="
			}
			link: (scope, element, attrs) ->
				pdfListView = new PDFListView element.find(".pdfjs-viewer")[0],
					textLayerBuilder: TextLayerBuilder
					annotationsLayerBuilder: AnnotationsLayerBuilder
					highlightsLayerBuilder: HighlightsLayerBuilder
					ondblclick: (e) -> onDoubleClick(e)
					# logLevel: PDFListView.Logger.DEBUG
				pdfListView.listView.pageWidthOffset = 20
				pdfListView.listView.pageHeightOffset = 20

				scope.loading = false

				onProgress = (progress) ->
					scope.$apply () ->
						scope.progress = Math.floor(progress.loaded/progress.total*100)

				initializedPosition = false
				initializePosition = () ->
					return if initializedPosition
					initializedPosition = true

					if (scale = localStorage("pdf.scale"))?
						pdfListView.setScaleMode(scale.scaleMode, scale.scale)
					else
						pdfListView.setToFitWidth()

					if (position = localStorage("pdf.position.#{attrs.key}"))
						pdfListView.setPdfPosition(position)

					scope.position = pdfListView.getPdfPosition(true)

					$(window).unload () =>
						localStorage "pdf.scale", {
							scaleMode: pdfListView.getScaleMode()
							scale: pdfListView.getScale()
						}
						localStorage "pdf.position.#{attrs.key}", pdfListView.getPdfPosition()

				flashControls = () ->
					scope.flashControls = true
					$timeout () ->
						scope.flashControls = false
					, 1000

				element.find(".pdfjs-viewer").scroll () ->
					scope.position = pdfListView.getPdfPosition(true)

				onDoubleClick = (e) ->
					scope.dblClickCallback?(page: e.page, offset: { top: e.y, left: e.x })

				scope.$watch "pdfSrc", (url) ->
					if url
						scope.loading = true
						scope.progress = 0

						pdfListView
							.loadPdf(url, onProgress)
							.then () ->
								scope.$apply () ->
									scope.loading = false
									delete scope.progress
									initializePosition()
									flashControls()

				scope.$watch "highlights", (areas) ->
					return if !areas?
					highlights = for area in areas or []
						{
							page: area.page - 1
							highlight:
								left: area.h
								top: area.v
								height: area.height
								width: area.width
						}

					if highlights.length > 0
						first = highlights[0]
						pdfListView.setPdfPosition({
							page: first.page
							offset:
								left: first.highlight.left
								top: first.highlight.top - 80
						}, true)

					pdfListView.clearHighlights()
					pdfListView.setHighlights(highlights, true)
					
					setTimeout () =>
						pdfListView.clearHighlights()
					, 1000

				scope.fitToHeight = () ->
					pdfListView.setToFitHeight()

				scope.fitToWidth = () ->
					pdfListView.setToFitWidth()

				scope.zoomIn = () ->
					scale = pdfListView.getScale()
					pdfListView.setScale(scale * 1.2)

				scope.zoomOut = () ->
					scale = pdfListView.getScale()
					pdfListView.setScale(scale / 1.2)

				if attrs.resizeOn?
					for event in attrs.resizeOn.split(",")
						scope.$on event, () ->
							pdfListView.onResize()

			template: """
				<div class="pdfjs-viewer"></div>
				<div class="pdfjs-controls" ng-class="{'flash': flashControls }">
					<div class="btn-group">
						<a href
							class="btn btn-info btn-lg"
							ng-click="fitToWidth()"
							tooltip="Fit to Width"
							tooltip-append-to-body="true"
							tooltip-placement="bottom"
						>
							<i class="fa fa-fw fa-arrows-h"></i>
						</a>
						<a href
							class="btn btn-info btn-lg"
							ng-click="fitToHeight()"
							tooltip="Fit to Height"
							tooltip-append-to-body="true"
							tooltip-placement="bottom"
						>
							<i class="fa fa-fw fa-arrows-v"></i>
						</a>
						<a href
							class="btn btn-info btn-lg"
							ng-click="zoomIn()"
							tooltip="Zoom In"
							tooltip-append-to-body="true"
							tooltip-placement="bottom"
						>
							<i class="fa fa-fw fa-search-plus"></i>
						</a>
						<a href
							class="btn btn-info btn-lg"
							ng-click="zoomOut()"
							tooltip="Zoom Out"
							tooltip-append-to-body="true"
							tooltip-placement="bottom"
						>
							<i class="fa fa-fw fa-search-minus"></i>
						</a>
					</div>
				</div>
				<div class="progress-thin" ng-show="loading">
					<div class="progress-bar" ng-style="{ 'width': progress + '%' }"></div>
				</div>
			"""
		}
	]