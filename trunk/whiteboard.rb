#!/usr/bin/env ruby -w
$VERBOSE = true; $:.unshift File.dirname($0)

#whiteboard

require 'Qt'
require 'pp'
require 'enum'
require 'mainwindow'
require 'logger'

class WhiteboardMainWindow < WhiteboardMainWindowUI
	slots 'insertRectangle()', 'insertMath()'

	def insertRectangle()
		@widget.insertRectangle #hacky
	end
	
	def insertMath()
		@widget.insertMath #hacky
	end

	def initialize()
		super
		@toolbar = Qt::ToolBar.new("hello", self)
		@toolbar.label = "hello"
		@toolbar.addSeparator()
		@toolbar.show()

		menuBar().insertItem("&File", Qt::PopupMenu.new(self))

		statusBar().message("Welcome to whiteboard!", 2000)

		@widget = WhiteboardMainWidget.new(self)
		@widget.show()
		setCentralWidget(@widget)

		connect( @insertRectangleAction, SIGNAL('activated()'), SLOT('insertRectangle()') )
		connect( @insertMathAction, SIGNAL('activated()'), SLOT('insertMath()') )
	end
end

class ControlPoint < Qt::CanvasRectangle
	attr_reader :parent

	def	initialize(boundingRect, canvas, parent)
		super(boundingRect, canvas)
		@parent = parent
	end
end

class WhiteboardObjectController
	signals 'itemCreated(WhiteboardObject)', 'itemModified(WhiteboardObject)'

	def initialize(mainWidget)
		$log.info caller.join("\n")
		@canvas = mainWidget.canvas
		@mainWidget = mainWidget
	end

	def mousePress(e)
	end

	def mouseMove(e)
	end

	def mouseRelease(e)
	end

	def create(p)
	end

	def objectSelected(o)
	end
end

class WhiteboardObject
	attr_reader :canvasItems, :isResizable
end

# getting ready for this
#class WhiteboardRectangle < WhiteboardObject
#	def initialize(canvas, e)
#		@canvasRect = Qt::CanvasRectangle.new(e.pos.x, e.pos.y, 1, 1, canvas)
#		@canvasRect.show
#
#		#@canvasItems = [@canvasRect]
#		@isResizable = true
#	end
#
#	def move(x, y) @canvasRect.move(x, y) end
#	def setSize(x, y) @canvasRect.setSize(x, y) end
#end

#class WhiteboardMathObject < WhiteboardObject
#	def initialize(canvas, e)
#
#end

class RectangleController < WhiteboardObjectController
	def initialize(mainWidget)
		super(mainWidget)
	end

	def create(p)
	end

	def mousePress(e)
		@point1 = Qt::Point.new(e.x, e.y)
		#@rect = WhiteboardRectangle.new(@canvas, e) #Qt::CanvasRectangle.new(e.pos.x, e.pos.y, 1, 1, @canvas)
		@rect = Qt::CanvasRectangle.new(e.pos.x, e.pos.y, 1, 1, @canvas)
		@rect.show
	end

	def mouseMove(e)
		point2 = Qt::Point.new(e.pos.x, e.pos.y)
		points = (@point1.x < point2.x) ? [@point1, point2] : [point2, @point1]
		@rect.move(points[0].x, points[0].y)
		size = points[1] - points[0]
		@rect.setSize(size.x, size.y)
		@canvas.update()
	end

	def mouseRelease(e)
		$log.info "creating rectangle"
		@mainWidget.createItem(@rect)
	end
end

class MathController < WhiteboardObjectController
	def initialize(mainWidget)
		super(mainWidget)
	end

	def mousePress(e)
		@point = Qt::Point.new(e.pos.x - @mainWidget.canvasView.x, e.pos.y - @mainWidget.canvasView.y)
		@mainWidget.showTextPanel
	end	

	def updateText(text)
		system("kopete_latexconvert.sh '" + text + "'")
		image = Qt::Image.new("out.png")
		pix = Qt::CanvasPixmapArray.new([Qt::Pixmap.new(image)])
		sprite = Qt::CanvasSprite.new(pix, @mainWidget.canvas)
		sprite.move(@point.x, @point.y)
		sprite.show

		# we put the pixmap onto an array that will be kept, otherwise
		# we get a segfault on garbage collection
		@mainWidget.pixmaps << pix 

		@mainWidget.hideTextPanel
		@mainWidget.createItem(sprite)
	end

	def objectSelected(o)
		#@mainWidget.setText(o.
		@mainWidget.showTextPanel
	end

end

class WhiteboardView < Qt::CanvasView

	signals 'math()', 'mousePress(QMouseEvent*)', 'mouseMove(QMouseEvent*)', 'mouseRelease(QMouseEvent*)'
	
	def contentsMousePressEvent(e)
		super
		emit mousePress(e)
	end

	def contentsMouseMoveEvent(e)
		super
		emit mouseMove(e)
	end

	def contentsMouseReleaseEvent(e) 
		super
		emit mouseRelease(e)
	end
end

class WhiteboardMainWidget < Qt::Widget
	attr_reader :canvasView, :canvas, :pixmaps

	slots 'math()', 'update()', 'mousePress(QMouseEvent*)', 'mouseMove(QMouseEvent*)', 'mouseRelease(QMouseEvent*)'

	$controlPointSize = 10
	$objectMinimumSize = 10
	$numRectangleControlPoints = 8

	def initialize(parent)
		super(parent)
				
		layout = Qt::GridLayout.new(self, 2, 2)

		@canvas = Qt::Canvas.new(2000, 2000)
		@canvas.resize( 1000, 1000 )
		@canvasView = WhiteboardView.new( @canvas, self )
		@canvasView.show()

		@textBox = Qt::TextEdit.new(self)

		@updateButton = Qt::PushButton.new('&Update', self)

		layout.addMultiCellWidget(@canvasView, 0, 0, 0, 0)
		layout.addWidget(@textBox, 1, 0)
		layout.addWidget(@updateButton, 1, 1)

		connect(@updateButton, SIGNAL('clicked()'), SLOT('update()'))
		connect(@canvasView, SIGNAL('math()'), SLOT('math()'))
		connect(@canvasView, SIGNAL('mousePress(QMouseEvent*)'), SLOT('mousePress(QMouseEvent*)'))
		connect(@canvasView, SIGNAL('mouseMove(QMouseEvent*)'), SLOT('mouseMove(QMouseEvent*)'))
		connect(@canvasView, SIGNAL('mouseRelease(QMouseEvent*)'), SLOT('mouseRelease(QMouseEvent*)'))

		@textBox.hide
		@updateButton.hide
		
		@@states = Enum.new(:Default, :Selecting, :Resizing, :Creating)
		@@mouseStates = Enum.new(:Down, :Up)

		@canvas = canvas
		
		# @selected will be an array containing the selected objects
		# unless @state is Resizing, in which case it will be a 
		# singleton array holding the selected control point
		@selected = []

		# when a single object is selected, control points are 
		# drawn at each corner of the object and at the middle of each edge,
		# to allow the object to be resized
		@controlPoints = []

		@parent = parent

		@state = @@states::Default
		@mouseButtonState = @@mouseStates::Up

		@selectedBrush = Qt::Brush.new(Qt::black)
		@nonSelectedBrush = Qt::Brush.new(Qt::white)
		
		@canvasItems = []

		@items = [] # move this into a different class eventually
								# (this class should only contain the canvas items (maybe))
		
		@pixmaps = [] # we keep all the pixmaps to avoid segfaults on garbage collection

		show()
	end

	def mousePress(e)
		list = @canvas.collisions(e.pos)

		if @state == @@states::Creating
			$log.info "mouse click in Creating state"
			@controller.mousePress(e)
		elsif list.empty?
			@state = @@states::Selecting if @state == @@states::Default
			@selectionRectangle = Qt::CanvasRectangle.new(e.pos.x, e.pos.y, 1, 1, @canvas)
			# we keep the original point from which the rectangle is repeatedly drawn
			@selectionPoint1 = Qt::Point.new(e.pos.x, e.pos.y)
			@selectionRectangle.show
			@selected = []
			@controlPoints.each { |c| c.hide() }
			@controlPoints = []
		else 
			if @controlPoints.index(list[0]) != nil
				# go to the Resizing state if we click on a control point

				@selected = [list[0]]
				@state = @@states::Resizing
			elsif @selected.index(list[0]) == nil
				# i.e, if we click on an object that is already selected, do nothing
				
				@selected = [list[0]]
				$log.info "new object selected"
			
				if @canvasItems.index(list[0]) != nil
					$log.info "and it's a canvas item"
					# if we clicked on an object (not a control point)
					@state = @@states::Default
					if @selected.length == 1
						drawControlPoints(list[0]) 
					end
				end
			end
		end
		@mouseButtonState = @@mouseStates::Down
		@mousePos = Qt::Point.new(e.x, e.y)

		@canvas.update
		$log.info "got the mouse press signal"
	end

	def mouseMove(e)
		if @state == @@states::Creating
			@controller.mouseMove(e)
		elsif @state == @@states::Selecting
			point2 = Qt::Point.new(e.pos.x, e.pos.y)
			points = (@selectionPoint1.x < point2.x) ? [@selectionPoint1, point2] : [point2, @selectionPoint1]
			@selectionRectangle.move(points[0].x, points[0].y)
			size = points[1] - points[0]
			@selectionRectangle.setSize(size.x, size.y)

			collisions = @canvas.collisions(@selectionRectangle.rect)
			@selected = @canvasItems.select{|r| collisions.index(r) != nil}

			if @selected.length == 1	
				drawControlPoints(@selected[0])
			else
				@controlPoints.each { |c| c.hide() }
				@controlPoints = []
			end
		else
			@selected.each { |i| i.moveBy(e.x - @mousePos.x, e.y - @mousePos.y) }
			dx, dy = e.pos.x - @mousePos.x, e.pos.y - @mousePos.y

			if @controlPoints.index(@selected[0]) != nil
				# we're resizing an object by dragging the control point
				
				currentObject = @selected[0].parent
				cp = @rectHash[@selected[0]]
				newWidth = currentObject.width + cp[0]*dx
				newHeight = currentObject.height + cp[1]*dy
				# to avoid strangeness when we resize an object to zero size
				# we stop the user from moving the control point to a size smaller than 5
				# todo: make this better
				if newWidth < 5 or newHeight < 5 
					Qt::Cursor.setPos(mapToGlobal(@mousePos))
					return
				end
				currentObject.setSize(newWidth, newHeight)
				currentObject.moveBy(cp[0] == -1 ? dx : 0, cp[1] == -1 ? dy : 0) 
				updateControlPoints(currentObject.boundingRect)
			else
				# we only draw control points if there is only one object selected
				# todo: draw control points over the total bounding rect of selected objects
				updateControlPoints(@selected[0].boundingRect) if @selected.length == 1
			end
		end	

		@canvas.update
		@mousePos = Qt::Point.new(e.x, e.y)
	end

	def mouseRelease(e)
		@mouseButtonState = @@mouseStates::Up
		if @state == @@states::Creating
			@controller.mouseRelease(e)
		elsif @state == @@states::Selecting
			@selectionRectangle.hide
			@selectionRectangle = nil
			@canvas.update
			@state = @@states::Default
		end
	end

	def updateControlPoints(br)
		@rectHash = {}
		i = 0
		for x in [[-1, br.left], [0, (br.right+br.left)/2], [1, br.right]]
			for y in [[-1, br.top], [0, (br.top+br.bottom)/2], [1, br.bottom]]
				if x[1] != (br.right+br.left)/2 or y[1] != (br.top+br.bottom)/2
					@controlPoints[i].move(x[1] - $controlPointSize/2, y[1] - $controlPointSize/2)
					@rectHash[@controlPoints[i]] = [x[0], y[0]]
					i += 1
				end
			end
		end
	end

	def createItem(object)
		@canvasItems << object
		@controller = nil
		@state = @@states::Default
		@canvas.update
	end

	def insertRectangle()
		@controller = RectangleController.new(self)
		@state = @@states::Creating
	end
	
	def insertMath()
		@controller = MathController.new(self)
		@state = @@states::Creating
	end

	def updateText(text)
		@controller.updateText(text)
	end

	def drawControlPoints(o)
		@controlPoints.each { |c| c.hide() }
		@controlPoints = []
		8.times {
			rect = ControlPoint.new(Qt::Rect.new(0, 0, 10, 10), @canvas, o)
			rect.z = 1 # control points go on top of object
			rect.show()
			@controlPoints << rect
		}

		updateControlPoints(o.boundingRect)
	end

	def setText(text)
		@textBox.text = text
	end

	def showTextPanel()
		@textBox.show
		@textBox.setFocus
		@updateButton.show
	end

	def hideTextPanel()
		@textBox.hide
		@updateButton.hide
	end

	def update()
		updateText(@textBox.text)
	end
end

$log = Logger.new("whiteboard.log", 5, 10*1024)
$log.level = Logger::DEBUG
a = Qt::Application.new(ARGV)
w = WhiteboardMainWindow.new()
w.resize(450, 300)
w.show()
a.setMainWidget(w)
#Qt::Internal::setDebug Qt::QtDebugChannel::QTDB_GC
a.exec
