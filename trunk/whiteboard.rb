#!/usr/bin/env ruby -w
$VERBOSE = true; $:.unshift File.dirname($0)

require 'Qt'
require 'pp'
require 'enum'
require 'mainwindow'
require 'logger'
require 'object'
require 'rectangle'
require 'math'
require 'line'
require 'network'
require 'drb'
require 'yaml'

class Qt::Rect
	def to_s
		"(#{x}, #{y}), (#{x + width}, #{y + height})"
	end
end
	
def total_bounding_rect(rects)
	left, right, top, bottom = rects[0].left, rects[0].right, rects[0].top, rects[0].bottom
	(1...rects.length).each do |i|
		rect = rects[i]
		left = rect.left if rect.left < left
		right = rect.right if rect.right > right
		top = rect.top if rect.top < top
		bottom = rect.bottom if rect.bottom > bottom
	end
	Qt::Rect.new(Qt::Point.new(left, top), Qt::Point.new(right, bottom))
end

class WhiteboardMainWindow < WhiteboardMainWindowUI
  slots 'math()', 'update()', 'mousePress(QMouseEvent*)', 'mouseMove(QMouseEvent*)', 'mouseRelease(QMouseEvent*)', 
		'insert_rectangle()', 'insert_math()', 'insert_line()', 'timeout()', 'networkEvent(QString*)', 
		'connection(QString*, int)', 'network_connect()'
	
	def timeout() end

	def networkEvent(s)
		m = s.match(Regexp.new('creating:(.*)', Regexp::MULTILINE))
		if m != nil
			puts "matched #{m[1]}"
			r = YAML.load(m[1].to_s).to_actual_object(@widget) 
			@widget.create_object(r, false)
			#@widget.insert_rectangle()
#			@widget.left_mouse_press(10, 10)
#			@widget.left_mouse_move(30, 30)
#			@widget.left_mouse_release(30, 30)
		end
		statusBar().message(s, 3000)
	end

	def connection(addr, port)
		statusBar().message("Connection! #{addr}:#{port}", 3000)
	end

	def network_connect()
		text = Qt::InputDialog.get_text('Whiteboard', 'Please enter the address (host:port) to connect to:')
		if text != nil
			address, port = text.split(':')
			@network_interface.add_peer(address, port.to_i)
		end
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

    connect( @insertRectangleAction, SIGNAL('activated()'), @widget, SLOT('insert_rectangle()') )
    connect( @insertMathAction, SIGNAL('activated()'), @widget, SLOT('insert_math()') )
    connect( @insertLineAction, SIGNAL('activated()'), @widget, SLOT('insert_line()') )
		connect(@connectAction, SIGNAL('activated()'), SLOT('network_connect()'))
		
		# timer is an unfortunate hack to get the network thread called.
		# apparently you need to execute some ruby code periodically otherwise
		# the ruby threads will never execute
		timer = Qt::Timer.new(self)
		connect(timer, SIGNAL('timeout()'), SLOT('timeout()'))
		timer.start(0)

		@network_interface = NetworkInterface.new(ARGV[1] || 2626)
		remove_this = ARGV[0][1..-1]
		set_caption("Whiteboard: #{remove_this}:#{ARGV[1] || 2626}")
		connect(@network_interface, SIGNAL('event(QString*)'), SLOT('networkEvent(QString*)'))
		connect(@network_interface, SIGNAL('connection(QString*, int)'), SLOT('connection(QString*, int)'))
		t = Thread.new { @network_interface.run() }

		@widget.network_interface = @network_interface
  end
end

class ControlPoint < Qt::CanvasRectangle
  attr_reader :parent
	attr_writer :parent

  def	initialize(boundingRect, canvas, parent = nil)
    super(boundingRect, canvas)
    @parent = parent
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

class WhiteboardState
  attr_reader :controller, :selected_objects, :selected_control_point, :objects, :canvas_items, :state,
		:total_selection_object

  def initialize()
    @@states = Enum.new(:Default, :Selecting, :Resizing, :Creating)
    
    @selected_objects = []
		@selected_control_point = nil
		@total_selection_object = nil
    @state = @@states::Default
    @canvas_items = []
    @objects = [] 
  end

  def deselect_all()
    @state = @@states::Selecting if @state == @@states::Default
    @selected_objects = []
		@selected_control_point = nil
		@total_selection_object = nil
  end

  def prepare_object_creation(controller)
    @controller = controller
    @state = @@states::Creating
  end

  def resize_object(cp)
    @selected_control_point = cp
		@total_selection_object = WhiteboardCompositeObject.new(selected_objects)
    @state = @@states::Resizing
  end

  def select_objects(o)
    @selected_objects = o
  end
  
  def create_object(object)
		@objects << object
    object.canvas_items.each { |it| @canvas_items << it }
    @controller = nil
    @state = @@states::Default
  end

  def set_default()
    @state = @@states::Default
  end

  def creating?() @state == @@states::Creating end
  def selecting?() @state == @@states::Selecting end
  def resizing?() @state == @@states::Resizing end

	def to_s() @state.to_s end
end

class WhiteboardMainWidget < Qt::Widget
  attr_reader :canvasView, :canvas, :pixmaps, :state, :network_interface
	attr_writer :network_interface

  slots 'math()', 'update()', 'mousePress(QMouseEvent*)', 'mouseMove(QMouseEvent*)', 'mouseRelease(QMouseEvent*)', 
		'insert_rectangle()', 'insert_math()', 'insert_line()', 'timeout()', 'networkEvent(QString*)', 
		'connection(QString*, int)'
  
	ControlPointSize = 10
  ObjectMinimumSize = 5
	NumControlPoints = 8


  def initialize(parent)
    super(parent)
        
    layout = Qt::GridLayout.new(self, 2, 2)

    @canvas = Qt::Canvas.new(2000, 2000)
    @canvas.resize( 1000, 1000 )
    @canvasView = WhiteboardView.new( @canvas, self )
    @canvasView.show()

    @text_box = Qt::TextEdit.new(self)

    @update_button = Qt::PushButton.new('&Update', self)

    layout.addMultiCellWidget(@canvasView, 0, 0, 0, 0)
    layout.addWidget(@text_box, 1, 0)
    layout.addWidget(@update_button, 1, 1)

    connect(@update_button, SIGNAL('clicked()'), SLOT('update()'))
    connect(@canvasView, SIGNAL('math()'), SLOT('math()'))
    connect(@canvasView, SIGNAL('mousePress(QMouseEvent*)'), SLOT('mousePress(QMouseEvent*)'))
    connect(@canvasView, SIGNAL('mouseMove(QMouseEvent*)'), SLOT('mouseMove(QMouseEvent*)'))
    connect(@canvasView, SIGNAL('mouseRelease(QMouseEvent*)'), SLOT('mouseRelease(QMouseEvent*)'))

    @text_box.hide
    @update_button.hide
    
    @@mouseStates = Enum.new(:Down, :Up)
    @mouse_button_state = @@mouseStates::Up

    @parent = parent

    @selectedBrush = Qt::Brush.new(Qt::black)
    @nonSelectedBrush = Qt::Brush.new(Qt::white)

    @state = WhiteboardState.new()
    
    # when a single object is selected, control points are 
    # drawn at each corner of the object and at the middle of each edge,
    # to allow the object to be resized
    @control_points = []

		@network_interface = nil
		
    show()
  end

  def mousePress(e)
    list = @canvas.collisions(e.pos)

    if @state.creating? 
      @state.controller.mousePress(e)
    elsif list.empty?
      @state.deselect_all()

      @selection_rectangle = Qt::CanvasRectangle.new(e.pos.x, e.pos.y, 1, 1, @canvas)
      # we keep the original point from which the rectangle is repeatedly drawn
      @selectionPoint1 = Qt::Point.new(e.pos.x, e.pos.y)
      @selection_rectangle.show()
      @control_points.each { |c| c.hide() }
      @control_points = []
    else 
      if @control_points.index(list[0]) != nil
        # go to the Resizing state if we click on a control point
        @state.resize_object(list[0])

      elsif @state.selected_objects.index(list[0].associated_object) == nil
        # i.e, if we click on an object that is already selected, do nothing
        @state.select_objects([list[0].associated_object])
				if @state.selected_objects.length == 1
					@state.selected_objects[0].select_object()
				end
				@state.set_default()
        create_control_points() 
      end
    end
    @mouse_button_state = @@mouseStates::Down
    @mouse_pos = Qt::Point.new(e.x, e.y)

    @canvas.update()
  end
  
  def create_object(item, broadcast = true)	
		puts "well we're creating a #{item.class.to_s} objeck"
    @state.create_object(item)
    @canvas.update()
		if broadcast == true and @network_interface != nil then
			puts "we got here coz broadcast is true"
			remove_this = (ARGV[0])[1..-1]
			@network_interface.broadcast_string("hello:#{remove_this}:#{ARGV[1]}", nil)
			@network_interface.broadcast_string("creating:#{YAML.dump(item.to_yaml_object()).to_s}", nil)
		end
		#j = YAML.load(YAML.dump(item.to_yaml_object())).to_actual_object(self) 
		#j.set_main_widget(self)
  end

  def mouseMove(e)
    if @state.creating?
      @state.controller.mouseMove(e)
    elsif @state.selecting?
      point1, point2 = @selectionPoint1, e.pos
      point1, point2 = point2, point1 if point2.x < point1.x
      @selection_rectangle.move(point1.x, point1.y)
      size = point2 - point1
      @selection_rectangle.setSize(size.x, size.y)
      @selection_rectangle.show()

      @canvas.update()

      collisions = @canvas.collisions(@selection_rectangle.rect)
      @state.select_objects(@state.canvas_items.select{|r| collisions.index(r) != nil}.map{|i| i.associated_object})
      create_control_points()
			if @state.selected_objects.length > 0
				update_control_points()		
			end
    elsif @state.resizing?
			dx, dy = e.pos.x - @mouse_pos.x, e.pos.y - @mouse_pos.y
			@state.selected_control_point.move_by(dx, dy)
        
			current_object = @state.total_selection_object
			cp = @rect_hash[@state.selected_control_point]
			new_width = current_object.width + cp[0]*dx
			new_height = current_object.height + cp[1]*dy

			# to avoid strangeness when we resize an object to zero size
			# we stop the user from moving the control point to a size smaller than ObjectMinimumSize
			# todo: make this better
			if new_width < ObjectMinimumSize or new_height < ObjectMinimumSize 
				Qt::Cursor.setPos(mapToGlobal(@mouse_pos))
				return
			end
			current_object.set_size(new_width, new_height)
			current_object.move_by(cp[0] == -1 ? dx : 0, cp[1] == -1 ? dy : 0) 
			update_control_points()
		else
			@state.selected_objects.each { |i| i.move_by(e.x - @mouse_pos.x, e.y - @mouse_pos.y) }

			selected = @state.selected_objects

			if selected.length > 0
				update_control_points()
			else
				@control_points.each { |c| c.hide() }
				@control_points = []
			end
			if selected.length == 1
				selected[0].select_object()
			end
		end

    @canvas.update
    @mouse_pos = Qt::Point.new(e.x, e.y)
  end

  def mouseRelease(e)
    @mouse_button_state = @@mouseStates::Up
    if @state.creating?
      @state.controller.mouseRelease(e)
    elsif @state.selecting?
      @selection_rectangle.hide
      @selection_rectangle = nil
      @canvas.update
      @state.set_default()
		elsif @state.resizing?
			@state.set_default()
		end
  end

  def update_control_points()
		br = total_bounding_rect(@state.selected_objects.map {|i| i.bounding_rect})
    @rect_hash = {}
    i = 0
    for x in [[-1, br.left], [0, (br.right+br.left)/2], [1, br.right]]
      for y in [[-1, br.top], [0, (br.top+br.bottom)/2], [1, br.bottom]]
        if x[1] != (br.right+br.left)/2 or y[1] != (br.top+br.bottom)/2
          @control_points[i].move(x[1] - ControlPointSize/2, y[1] - ControlPointSize/2)
          @rect_hash[@control_points[i]] = [x[0], y[0]]
          i += 1
        end
      end
    end
  end

  def insert_rectangle()
    @state.prepare_object_creation(WhiteboardRectangle.new(self))
  end
  
  def insert_math()
    @state.prepare_object_creation(WhiteboardMathObject.new(self))
  end
  
	def insert_line()
    @state.prepare_object_creation(WhiteboardLine.new(self))
  end

	def left_mouse_press(x, y)
		mousePress(Qt::MouseEvent.new(Qt::Event::MouseButtonPress, Qt::Point.new(x, y), Qt::LeftButton, 0))
	end

	def left_mouse_move(x, y)
		mouseMove(Qt::MouseEvent.new(Qt::Event::MouseMove, Qt::Point.new(x, y), Qt::LeftButton, 0))
	end

	def left_mouse_release(x, y)
		mouseRelease(Qt::MouseEvent.new(Qt::Event::MouseButtonRelease, Qt::Point.new(x, y), Qt::LeftButton, 0))
	end


  def update_text(text)
		if @state.creating?
			@state.controller.update_text(text)
		else
			@state.selected_objects[0].controller.update_text(text)
		end
  end

  def create_control_points()
    if @state.selected_objects.length > 0
      @control_points.each { |c| c.hide() }
      @control_points = []
      NumControlPoints.times {
        rect = ControlPoint.new(Qt::Rect.new(0, 0, 10, 10), @canvas, WhiteboardCompositeObject.new(@state.selected_objects))
        rect.z = 1 # control points go on top of object
        rect.show()
        @control_points << rect
      }

			update_control_points()
    else
      @control_points.each { |c| c.hide() }
      @control_points = []
    end
  end

  def setText(text)
    @text_box.text = text
  end

  def show_text_panel(text = nil)
		@text_box.text = text if text != nil
    @text_box.show
    @text_box.setFocus
    @update_button.show
  end

  def hide_text_panel()
    @text_box.hide
    @update_button.hide
  end

  def update()
    update_text(@text_box.text)
  end
end


