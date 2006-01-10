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
require 'image'
require 'network'
require 'object_popupmenu'
require 'yaml'

# Takes an array of rectangles and returns the smallest rectangle
# that encloses them all.
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
  slots 'timeout()', 'networkEvent(QString*)', 'networkMessage(QString*)',
		'network_connect()', 'start_server()', 'file_save()', 'file_open()',
		'insert_rectangle()', 'insert_math()', 'insert_line()', 'insert_arrow()', 'insert_image()',
		'no_item_creating()'
	
	def timeout() end

	def networkMessage(s)
		msg = NetworkMessage.from_line(s)
		if msg.is_a?(CreateObjectMessage)
			@widget.create_object(msg.object.from_yaml_object(@widget), false)
		elsif msg.is_a?(MoveObjectMessage)
			@widget.move_object(msg.object_id, msg.x, msg.y)
		elsif msg.is_a?(ResizeObjectMessage)
			@widget.resize_object_by_id(msg.object_id, msg.mx, msg.my, msg.dx, msg.dy)
		elsif msg.is_a?(DeleteObjectMessage)
			@widget.delete_object_by_id(msg.object_id)
		elsif msg.is_a?(ChangeObjectMessage)
			@widget.change_object(msg.object_id, msg.object)
		end
	end

	def connection(addr, port)
		statusBar().message("Connection! #{addr}:#{port}", 3000)
	end

	def network_connect()
		text = Qt::InputDialog.get_text('Whiteboard', 'Please enter the address (host:port) to connect to:')
		if text != nil
			address, port = text.split(':')
			@network_interface.start_client(address, port.to_i)
			statusBar().message("Connected", 2000)
		else
			statusBar().message("Connection cancelled", 2000)
		end
	end	

	def start_server()
		@network_interface.start_server(@port)
		statusBar().message("Server started on port #{@port}", 3000)
	end

	def file_save()
		name = Qt::FileDialog.get_save_file_name(
			"~/", 
			"Whiteboard files (*.wb)",
			self,
			"save file dialog",
			"Please choose a filename to save to"
		)
		if name != nil then
			File.open(name, "w+") do |f|
				@widget.state.objects.each { |o| f.puts(o.to_s.tr("\n", '#')) }
			end
		end
	end

	def file_open()
		name = Qt::FileDialog.get_open_file_name(
			"~/", 
			"Whiteboard files (*.wb)",
			self,
			"open file dialog",
			"Please choose a filename to save to"
		)
		if name != nil then
			#@widget.state.objects = []
			File.open(name, "r") do |f|
				f.each_line do |line|
					r = YAML.load(line.tr('#', "\n")).to_actual_object(@widget) 
					@widget.create_object(r, false)
				end
			end
		end
	end

  def initialize(port, parent = nil, name = nil)
    super(parent, name)

		@port = port

    statusBar().message("Welcome to whiteboard!", 2000)

    @widget = WhiteboardMainWidget.new(self)
    @widget.show()
    set_central_widget(@widget)

    connect(@fileSaveAction, SIGNAL('activated()'), SLOT('file_save()'))
    connect(@fileOpenAction, SIGNAL('activated()'), SLOT('file_open()'))

		@item_actions = [@insertRectangleAction, @insertMathAction, @insertLineAction, @insertArrowAction, @insertImageAction]

    connect(@insertRectangleAction, SIGNAL('activated()'), SLOT('insert_rectangle()'))
    connect(@insertMathAction, SIGNAL('activated()'), SLOT('insert_math()'))
    connect(@insertLineAction, SIGNAL('activated()'), SLOT('insert_line()'))
    connect(@insertArrowAction, SIGNAL('activated()'), SLOT('insert_arrow()'))
    connect(@insertImageAction, SIGNAL('activated()'), SLOT('insert_image()'))
		
		connect(@connectAction, SIGNAL('activated()'), SLOT('network_connect()'))
		connect(@startServerAction, SIGNAL('activated()'), SLOT('start_server()'))

		connect(@widget, SIGNAL('object_created()'), SLOT('no_item_creating()'))
		
		# timer is an unfortunate hack to get the network thread called.
		# apparently you need to execute some ruby code periodically otherwise
		# the ruby threads will never execute
		timer = Qt::Timer.new(self)
		connect(timer, SIGNAL('timeout()'), SLOT('timeout()'))
		timer.start(0)

		@network_interface = NetworkInterface.new()
		set_caption("Whiteboard: #{@port}")
		connect(@network_interface, SIGNAL('message(QString*)'), SLOT('networkMessage(QString*)'))

		@widget.network_interface = @network_interface

		setMinimumSize(800, 400)
  end

	def set_activated(it)
		@item_actions.each { |i| i.set_on(i == it) }
	end

	def no_item_creating() set_activated(nil) end

	def insert_rectangle()
		set_activated(@insertRectangleAction)	
		@widget.prepare_object_creation(WhiteboardRectangle.new(@widget))
	end

	def insert_math()
		set_activated(@insertMathAction)	
		m = WhiteboardMathObject.new(@widget)
		connect(m, SIGNAL('started_editing(QString*)'), @widget, SLOT('show_text_panel(QString*)'))
		connect(m, SIGNAL('finished_editing()'), @widget, SLOT('hide_text_panel()'))
		@widget.prepare_object_creation(m)
	end

	def insert_line()
		set_activated(@insertLineAction)	
		@widget.prepare_object_creation(WhiteboardLine.new(@widget))
	end

	def insert_arrow()
		set_activated(@insertArrowAction)	
		@widget.prepare_object_creation(WhiteboardArrow.new(@widget))
	end

	def insert_image()
		set_activated(@insertImageAction)	
		@widget.prepare_object_creation(WhiteboardImageObject.new(@widget))
	end
end

class ControlPoint < Qt::CanvasRectangle
  attr_reader :parent, :mx, :my
	attr_writer :parent

  def	initialize(boundingRect, canvas, parent = nil)
    super(boundingRect, canvas)
    @parent = parent
  end

	def set_multipliers(mx, my)
		@mx, @my = mx, my
	end

	def multipliers() [@mx, @my] end
end

class WhiteboardView < Qt::CanvasView
  signals 'mousePress(QMouseEvent*)', 'mouseMove(QMouseEvent*)', 'mouseRelease(QMouseEvent*)'
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
  attr_reader :canvas_view, :canvas, :pixmaps, :state, :network_interface
	attr_writer :network_interface

	signals 'object_created()'

  slots 'update()', 'mousePress(QMouseEvent*)', 'mouseMove(QMouseEvent*)', 'mouseRelease(QMouseEvent*)', 
		'insert_rectangle()', 'insert_math()', 'insert_line()', 'insert_arrow()', 'insert_image()',
		'show_text_panel(QString*)', 'hide_text_panel()', 'properties_changed(QString*)'
  
	ControlPointSize = 10
  ObjectMinimumSize = 5
	NumControlPoints = 8

  def initialize(parent)
    super(parent)
        
    layout = Qt::GridLayout.new(self, 2, 2)

    @canvas = Qt::Canvas.new(2000, 2000)
    @canvas.resize( 1000, 1000 )
    @canvas_view = WhiteboardView.new( @canvas, self )
    @canvas_view.show()

    @text_box = Qt::TextEdit.new(self)

    @update_button = Qt::PushButton.new('&Update', self)

    layout.addMultiCellWidget(@canvas_view, 0, 0, 0, 0)
    layout.addWidget(@text_box, 1, 0)
    layout.addWidget(@update_button, 1, 1)

    connect(@update_button, SIGNAL('clicked()'), SLOT('update()'))
    connect(@canvas_view, SIGNAL('mousePress(QMouseEvent*)'), SLOT('mousePress(QMouseEvent*)'))
    connect(@canvas_view, SIGNAL('mouseMove(QMouseEvent*)'), SLOT('mouseMove(QMouseEvent*)'))
    connect(@canvas_view, SIGNAL('mouseRelease(QMouseEvent*)'), SLOT('mouseRelease(QMouseEvent*)'))

    @text_box.hide()
    @update_button.hide()
    
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

		@network_interface = NetworkInterface.new()
		
    show()

		# these 3 lines to enable keyboard events
		set_enabled(true)
		set_focus_policy(Qt::Widget::StrongFocus)
		set_focus()
  end

	############
	# State Modification Functions
	############
 
	def prepare_object_creation(ob)
		@state.prepare_object_creation(ob)
		set_cursor(Qt::Cursor.new(Qt::CrossCursor))
	end
  
	def create_object(object, broadcast = true)	
    @state.create_object(object)
    @canvas.update()
		if broadcast and @network_interface != nil and @network_interface.started? then
			@network_interface.broadcast_message(CreateObjectMessage.new(object.to_yaml_object()))
		end

		# hack: we use broadcast == true because that means the object is 
		# created by the user rather than by a message etc.  do this properly
		# one day.
		if broadcast == true
			emit object_created() 
			set_cursor(Qt::Cursor.new(Qt::ArrowCursor))
		end
  end

	def move_object(whiteboard_object_id, x, y)
		@state.objects.find { |i| i.whiteboard_object_id == whiteboard_object_id }.move(x, y)
		@canvas.update()
	end

	def delete_object_by_id(whiteboard_object_id)
		@state.objects.each { |i| 
			if i.whiteboard_object_id == whiteboard_object_id
				i.hide() 
				# tag with whiteboard_object_id = nil so we remove it next
				i.whiteboard_object_id = nil 
			end
		}
		@state.objects.delete_if { |i| i.whiteboard_object_id == nil }
		@canvas.update()
	end

	def resize_object_by_id(whiteboard_object_id, mx, my, dx, dy)
		ob = @state.objects.find { |i| i.whiteboard_object_id == whiteboard_object_id }
		resize_object(ob, mx, my, dx, dy)
		@canvas.update()
	end

	def change_object(whiteboard_object_id, object)
		delete_object_by_id(whiteboard_object_id)
		ob = object.from_yaml_object(self)
		ob.whiteboard_object_id = whiteboard_object_id
		create_object(ob, false)
	end

	def resize_object(object, mx, my, dx, dy)
		new_width = object.width + mx*dx
		new_height = object.height + my*dy

		# to avoid strangeness when we resize an object to zero size
		# we stop the user from moving the control point to a size smaller than ObjectMinimumSize
		# todo: make this better
		if new_width < ObjectMinimumSize or new_height < ObjectMinimumSize 
			return false
		end
		object.set_size(new_width, new_height)
		object.move_by(mx == -1 ? dx : 0, my == -1 ? dy : 0) 
		true
	end

	############
	# Events
	############

  def mousePress(e)
		if (e.button == Qt::RightButton)
			p = ObjectPopupMenu.new(@state.selected_objects[0], self)
			connect(p, SIGNAL('properties_changed(QString*)'), SLOT('properties_changed(QString*)'))
			p.popup(e.global_pos)
			return
		end
    list = @canvas.collisions(e.pos)

    if @state.creating? 
      @state.controller.mousePress(e)
    elsif list.empty?
      @state.deselect_all()

			hide_text_panel()

      @selection_rectangle = Qt::CanvasRectangle.new(e.pos.x, e.pos.y, 1, 1, @canvas)
      # we keep the original point from which the rectangle is repeatedly drawn
      @selectionPoint1 = Qt::Point.new(e.pos.x, e.pos.y)
      @selection_rectangle.show()
      @control_points.each { |c| c.hide() }
      @control_points = []
    else 
      if @control_points.index(list[0]) != nil
				if list[0].mx.abs == 1 and list[0].my == 0
					set_cursor(Qt::Cursor.new(SizeHorCursor))
				elsif list[0].mx == 0 and list[0].my.abs == 1
					set_cursor(Qt::Cursor.new(SizeVerCursor))
				elsif list[0].mx == list[0].my
					set_cursor(Qt::Cursor.new(SizeFDiagCursor))
				else
					set_cursor(Qt::Cursor.new(SizeBDiagCursor))
				end

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
  
  def mouseMove(e)
		if (e.button == Qt::RightButton)
			return
		end
    if @state.creating?
      @state.controller.mouseMove(e)
    elsif @state.selecting?
      point1, point2 = @selectionPoint1, e.pos
      point1, point2 = point2, point1 if point2.x < point1.x
      @selection_rectangle.move(point1.x, point1.y)
      size = point2 - point1
      @selection_rectangle.setSize(size.x, size.y)
      @selection_rectangle.show()

      collisions = @canvas.collisions(@selection_rectangle.rect)
      @state.select_objects(@state.canvas_items.select{|r| collisions.index(r) != nil}.map{|i| i.associated_object})
      create_control_points()
    elsif @state.resizing?
			dx, dy = e.pos.x - @mouse_pos.x, e.pos.y - @mouse_pos.y
			cp = @state.selected_control_point.multipliers() 

			if not resize_object(@state.total_selection_object, cp[0], cp[1], dx, dy)
				Qt::Cursor.set_pos(mapToGlobal(@mouse_pos))
				return false
			end
			
			@state.selected_control_point.move_by(dx, dy)
			@network_interface.broadcast_message(ResizeObjectMessage.new(
				@state.selected_objects[0].whiteboard_object_id, cp[0], cp[1], dx, dy))
			update_control_points()
		else
			set_cursor(Qt::Cursor.new(Qt::SizeAllCursor))
				
			@state.selected_objects.each do |i|
				i.move_by(e.x - @mouse_pos.x, e.y - @mouse_pos.y)
				@network_interface.broadcast_message(MoveObjectMessage.new(i.whiteboard_object_id, i.x, i.y))
			end
			update_control_points()
			@state.selected_objects[0].select_object() if @state.selected_objects.length == 1
		end

    @canvas.update()
    @mouse_pos = Qt::Point.new(e.x, e.y)
  end

  def mouseRelease(e)
		if (e.button == Qt::RightButton)
			return
		end

    @mouse_button_state = @@mouseStates::Up
    if @state.creating?
      @state.controller.mouseRelease(e)
    elsif @state.selecting?
      @selection_rectangle.hide
      @selection_rectangle = nil
      @canvas.update()
      @state.set_default()
		elsif @state.resizing?
			@state.set_default()
		end

		set_cursor(Qt::Cursor.new(Qt::ArrowCursor))
  end

	def keyPressEvent(e)
		if e.key == Qt::Key_Delete and @state.selected_objects.length > 0
			#delete all selected objects
			@state.selected_objects.each do |o|
				o.hide()
				@state.objects.delete(o)
				@network_interface.broadcast_message(DeleteObjectMessage.new(o.whiteboard_object_id))
				o = nil
			end
			@state.deselect_all()
			update_control_points()
			@canvas.update()
		else
			e.ignore()
		end
	end

	def properties_changed(s)
		ob = @state.objects.find { |o| o.whiteboard_object_id == s }
		@network_interface.broadcast_message(ChangeObjectMessage.new(s, ob.to_yaml_object()))
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
		end
		
		update_control_points()
  end

  def update_control_points()
		if (@state.selected_objects.length > 0)
			br = total_bounding_rect(@state.selected_objects.map {|i| i.bounding_rect})
			i = 0
			for x in [[-1, br.left], [0, (br.right+br.left)/2], [1, br.right]]
				for y in [[-1, br.top], [0, (br.top+br.bottom)/2], [1, br.bottom]]
					if x[1] != (br.right+br.left)/2 or y[1] != (br.top+br.bottom)/2
						@control_points[i].move(x[1] - ControlPointSize/2, y[1] - ControlPointSize/2)
						@control_points[i].set_multipliers(x[0], y[0])
						i += 1
					end
				end
			end
		else
			@control_points.each { |c| c.hide() }
			@control_points = []
		end
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


