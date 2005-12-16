#!/usr/bin/env ruby
$VERBOSE = true; $:.unshift File.dirname($0)

require 'Qt'
require 'enum'
require 'mainwindow'

class WhiteboardMainWindow < WhiteboardMainWindowUI
	slots 'insertRectangle()'

	def insertRectangle()
		@widget.canvasView.insertRectangle #hacky
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
	end
end

class ControlPoint < Qt::CanvasRectangle
	attr_reader :parent

	def	initialize(boundingRect, canvas, parent)
		super(boundingRect, canvas)
		@parent = parent
	end
end

class WhiteboardView < Qt::CanvasView
	def initialize(canvas, parent)
		super(canvas, parent)
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

		@state = @@states::Default
		@mouseButtonState = @@mouseStates::Up

		@selectedBrush = Qt::Brush.new(Qt::black)
		@nonSelectedBrush = Qt::Brush.new(Qt::white)
		
		# just create some random objects to start off with
		@rects = []
		[0, 50, 100].each { |x|
			[0, 50, 100].each { |y|
				rect = Qt::CanvasRectangle.new(x, y, 30, 30, @canvas)
				rect.setBrush(@nonSelectedBrush) 
				rect.show
				@rects << rect
			}
		}

		show()
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

	def insertRectangle()
		@state = @@states::Creating
	end

	def drawControlPoints(o)
		@controlPoints.each { |c| c.hide() }
		@controlPoints = []
		for i in 1..8
			rect = ControlPoint.new(Qt::Rect.new(0, 0, 10, 10), @canvas, o)
			rect.z = 1 #control points go on top of object
			rect.show()
			@controlPoints << rect
		end

		updateControlPoints(o.rect)
	end

	def contentsMousePressEvent(e)
		super

		list = @canvas.collisions(e.pos)

		if list.empty? or @state == @@states::Creating # probably need to change this
			# clicked on empty space: deselect all
			
			@state = @@states::Selecting if @state == @@states::Default
			@selectionRectangle = Qt::CanvasRectangle.new(e.pos.x, e.pos.y, 1, 1, @canvas)
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
			
				if @rects.index(list[0]) != nil
					# if we clicked on an object (not a control point)
					@state = @@states::Default
					drawControlPoints(list[0]) if @selected.length == 1
				end
			end
		end
		@mouseButtonState = @@mouseStates::Down
		@mousePos = Qt::Point.new(e.x, e.y)

		setBrushes()
		@canvas.update
	end

	def setBrushes()
		@rects.each { |r| r.setBrush(@nonSelectedBrush) }
		@rects.each { |r|
			if (@state == @@states::Resizing and r == @selected[0].parent or @selected.index(r) != nil)
				r.setBrush(@selectedBrush)
			end
		}
	end

	def contentsMouseMoveEvent(e)
		super
		if @state == @@states::Selecting or @state == @@states::Creating
			point2 = Qt::Point.new(e.pos.x, e.pos.y)
			points = (@selectionPoint1.x < point2.x) ? [@selectionPoint1, point2] : [point2, @selectionPoint1]
			@selectionRectangle.move(points[0].x, points[0].y)
			size = points[1] - points[0]
			@selectionRectangle.setSize(size.x, size.y)

			collisions = @canvas.collisions(@selectionRectangle.rect)
			@selected = @rects.select{|r| collisions.index(r) != nil}

			setBrushes()
		
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
				@draggedObject = @selected[0]
				currentObject = @draggedObject.parent

				cp = @rectHash[@draggedObject]
				newWidth = currentObject.width + cp[0]*dx
				newHeight = currentObject.height + cp[1]*dy
				if newWidth < 5 or newHeight < 5 # this isn't very good
					Qt::Cursor.setPos(mapToGlobal(@mousePos))
					return
				end
				currentObject.setSize(newWidth, newHeight)
				currentObject.moveBy(cp[0] == -1 ? dx : 0, cp[1] == -1 ? dy : 0) 
				updateControlPoints(currentObject.boundingRect)
			else
				updateControlPoints(@selected[0].boundingRect) if @selected.length == 1
			end
		end	

		@canvas.update
		@mousePos = Qt::Point.new(e.x, e.y)
	end

	def contentsMouseReleaseEvent(e) 
		super
		@mouseButtonState = @@mouseStates::Up
		if @state == @@states::Selecting or @state == @@states::Creating
			if @state == @@states::Creating
				@rects << @selectionRectangle
			else
				@selectionRectangle.hide
				@selectionRectangle = nil
			end
			@canvas.update
			
			@state = @@states::Default
		end
	end
end


class WhiteboardMainWidget < Qt::Widget
	slots 'addEquation()' 
	
	attr_reader :canvasView

	$controlPointSize = 10
	$objectMinimumSize = 10
	$numRectangleControlPoints = 8

	def initialize(parent)
		super(parent)
				
		layout = Qt::GridLayout.new(self, 2, 2)

		@canvas = Qt::Canvas.new(2000, 2000)
		@canvas.resize( 300, 300 )
		@canvasView = WhiteboardView.new( @canvas, self )
		@canvasView.show()

		@textBox = Qt::TextEdit.new(self)
		@textBox.show()

		addButton = Qt::PushButton.new('&Add', self)
		addButton.show()

		connect( addButton, SIGNAL('clicked()'), SLOT('addEquation()') )

		layout.addMultiCellWidget(@canvasView, 0, 0, 0, 0)
		layout.addWidget(@textBox, 1, 0)
		layout.addWidget(addButton, 1, 1)
	end
end

a = Qt::Application.new(ARGV)
w = WhiteboardMainWindow.new()
w.resize(300, 300)
w.show()
a.setMainWidget(w)
#Qt::Internal::setDebug Qt::QtDebugChannel::QTDB_GC
a.exec
