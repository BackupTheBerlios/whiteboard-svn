#!/usr/bin/env ruby
$VERBOSE = true; $:.unshift File.dirname($0)

require 'Qt'

class Enum < Module
	class Member < Module
		attr_reader :enum, :index

		def initialize(enum, index)
			@enum, @index = enum, index
			extend enum
		end

		alias :to_int :index
		alias :to_i :index

		def <=>(other)
			@index <=> other.index
		end

		include Comparable
	end

	def initialize(*symbols, &block)
		@members = []
		symbols.each_with_index do |symbol, index|
			symbol = symbol.to_s.sub(/^[a-z]/) { |letter| letter.upcase }.to_sym
			member = Enum::Member.new(self, index)
			const_set(symbol, member)
			@members << member
		end
		super(&block)
	end

	def [](index) @members[index] end
	def size() @members.size end
	alias :length :size

	def first(*args) @members.first(*args) end
	def last(*args) @members.last(*args) end

	def each(&block) @members.each(&block) end
	include Enumerable
end


class WhiteboardMainWindow < Qt::MainWindow
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
	end
end

class ControlPoint < Qt::CanvasRectangle
	attr_reader :parent

	def	initialize(boundingRect, canvas, parent)
		super(boundingRect, canvas)
		@parent = parent
	end
end

class MyCanvasView < Qt::CanvasView
	def initialize(canvas, parent)
		super(canvas, parent)
		@@states = Enum.new(:Default, :Selecting)
		@@mouseStates = Enum.new(:Down, :Up)

		@canvas = canvas
		@selected = []
		@controlPoints = []
		@state = @@states::Default
		@mouseButtonState = @@mouseStates::Up

		@selectedBrush = Qt::Brush.new(Qt::black)
		@nonSelectedBrush = Qt::Brush.new(Qt::white)
		
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

	def updateRects(br)
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

	def contentsMousePressEvent(e)
		super

		list = @canvas.collisions(e.pos)
		if list.empty?
			@state = @@states::Selecting
			@selectionRectangle = Qt::CanvasRectangle.new(e.pos.x, e.pos.y, 1, 1, @canvas)
			@selectionPoint1 = Qt::Point.new(e.pos.x, e.pos.y)
			@selectionRectangle.show
			@selected = []
			@controlPoints.each { |c| c.hide() }
			@controlPoints = []
		else 
			if (@selected == nil or @selected.index(list[0]) == nil)
				@state = @@states::Default
				@selected = [list[0]]
			
				if @rects.index(list[0]) != nil
					@controlPoints.each { |c| c.hide() }
					@controlPoints = []
					for i in 1..8
						rect = ControlPoint.new(Qt::Rect.new(0, 0, 10, 10), @canvas, list[0])
						rect.z = 1 #control points go on top of object
						rect.show()
						@controlPoints << rect
					end
					updateRects(list[0].rect)
				end
			end
		end
		@mouseButtonState = @@mouseStates::Down
		@mousePos = Qt::Point.new(e.x, e.y)

		@rects.each { |r|
			r.setBrush(@selected.index(r) != nil ? @selectedBrush : @nonSelectedBrush)
		}
		@canvas.update
	end

	def contentsMouseMoveEvent(e)
		super
		if @state == @@states::Selecting
			point2 = Qt::Point.new(e.pos.x, e.pos.y)
			points = (@selectionPoint1.x < point2.x) ? [@selectionPoint1, point2] : [point2, @selectionPoint1]
			@selectionRectangle.move(points[0].x, points[0].y)
			size = points[1] - points[0]
			@selectionRectangle.setSize(size.x, size.y)

			collisions = @canvas.collisions(@selectionRectangle.rect)
			@selected = []
			@rects.each { |l|
				c = collisions.index(l) != nil
				if l != @selectionRectangle
					l.setBrush(c ? @selectedBrush : @nonSelectedBrush)
					@selected << l if c
				end
			}
		elsif
			@selected.each { |i| i.moveBy(e.x - @mousePos.x, e.y - @mousePos.y) }
			dx = e.pos.x - @mousePos.x
			dy = e.pos.y - @mousePos.y

			if @controlPoints.index(@selected[0]) != nil
				@draggedObject = @selected[0]
				@currentObject = @draggedObject.parent

				cp = @rectHash[@draggedObject]
				newWidth = @currentObject.width + cp[0]*dx
				newHeight = @currentObject.height + cp[1]*dy
				if newWidth < 5 or newHeight < 5
					#this is probably not as nice as it could be
					Qt::Cursor.setPos(mapToGlobal(@mousePos))
					return
				end
				@currentObject.setSize(newWidth, newHeight)
				@currentObject.moveBy(dx, 0) if cp[0] == -1
				@currentObject.moveBy(0, dy) if cp[1] == -1
				updateRects(@currentObject.boundingRect)
			else
				updateRects(@selected[0].boundingRect)
			end
		end	

		@canvas.update
		@mousePos = Qt::Point.new(e.x, e.y)
	end

	def contentsMouseReleaseEvent(e) 
		super
		@mouseButtonState = @@mouseStates::Up
		puts @mouseButtonState
		if @state == @@states::Selecting
			@state = @@states::Default
			@selectionRectangle.hide()
			@selectionRectangle = nil
		end
	end
end


class WhiteboardMainWidget < Qt::Widget
	slots 'addEquation()' 

	$controlPointSize = 10
	$objectMinimumSize = 10
	$numRectangleControlPoints = 8

	def initialize(parent)
		super(parent)
				
		layout = Qt::GridLayout.new(self, 2, 2)

		@canvas = Qt::Canvas.new(2000, 2000)
		@canvas.resize( 300, 300 )
		@canvasView = MyCanvasView.new( @canvas, self )
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

	def mousePressEvent(e)
		@mousePos = Qt::Point.new(e.pos.x, e.pos.y)
	end

	def mouseDoubleClickEvent(e)
	end

	def mouseReleaseEvent(e)
		@canvas.update()
	end

	def mouseMoveEvent(e)
	end
end

a = Qt::Application.new(ARGV)
w = WhiteboardMainWindow.new()
w.resize(300, 300)
w.show()
a.setMainWidget(w)
#Qt::Internal::setDebug Qt::QtDebugChannel::QTDB_GC
a.exec
