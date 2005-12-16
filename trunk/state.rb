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

class MyCanvasView < Qt::CanvasView
	def initialize(canvas, parent)
		super(canvas, parent)
		@@states = Enum.new(:Default, :Selecting)
		@@mouseStates = Enum.new(:Down, :Up)

		@canvas = canvas
		@selected = []
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

	def contentsMousePressEvent(e)
		super

		list = @canvas.collisions(e.pos)
		if list.empty?
			@state = @@states::Selecting
			@selectionRectangle = Qt::CanvasRectangle.new(e.pos.x, e.pos.y, 1, 1, @canvas)
			@selectionPoint1 = Qt::Point.new(e.pos.x, e.pos.y)
			@selectionRectangle.show
			@selected = []
		else 
			if (@selected == nil or @selected.index(list[0]) == nil)
				@state = @@states::Default
				@selected = [list[0]]
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
