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

class WhiteboardMainWindow < WhiteboardMainWindowUI
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
  attr_reader :controller, :selected_objects, :canvas_items

  def initialize()
    @@states = Enum.new(:Default, :Selecting, :Resizing, :Creating)
    
    # @selected will be an array containing the selected objects
    # unless @state is Resizing, in which case it will be a 
    # singleton array holding the selected control point
    @selected_objects = []
    @state = @@states::Default
    @canvas_items = []
    @items = [] 
  end

  def deselect_all()
    @state = @@states::Selecting if @state == @@states::Default
    @selected_objects = []
  end

  def prepare_object_creation(controller)
    @controller = controller
    @state = @@states::Creating
  end

  def resize_object(o)
    @selected_objects = [o]
    @state = @@states::Resizing
  end

  def select_objects(o)
    @selected_objects = o
  end
  
  def create_object(object)
    object.canvas_items.each { |it| @canvas_items << it }
    @controller = nil
    @state = @@states::Default
  end

  def set_default()
    @state = @@states::Default
  end

  def creating?() @state == @@states::Creating end
  def selecting?() @state == @@states::Selecting end
end

class WhiteboardMainWidget < Qt::Widget
  attr_reader :canvasView, :canvas, :pixmaps

  slots 'math()', 'update()', 'mousePress(QMouseEvent*)', 'mouseMove(QMouseEvent*)', 'mouseRelease(QMouseEvent*)', 
		'insert_rectangle()', 'insert_math()'

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
    
    @pixmaps = [] # we keep all the pixmaps to avoid segfaults on garbage collection
    
    # when a single object is selected, control points are 
    # drawn at each corner of the object and at the middle of each edge,
    # to allow the object to be resized
    @control_points = []

    show()
  end

  def mousePress(e)
    list = @canvas.collisions(e.pos)

    if @state.creating?  #todo
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
				@state.set_default()
        create_control_points() 
      end
    end
    @mouse_button_state = @@mouseStates::Down
    @mouse_pos = Qt::Point.new(e.x, e.y)

    @canvas.update
  end
  
  def create_object(item)	
    @state.create_object(item)
    @canvas.update
  end

  def mouseMove(e)
    if @state.creating?
      @state.controller.mouseMove(e) #todo
    elsif @state.selecting?
      $log.info "mouse move on selecting"
    
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
    else
      @state.selected_objects.each { |i| i.move_by(e.x - @mouse_pos.x, e.y - @mouse_pos.y) }
      dx, dy = e.pos.x - @mouse_pos.x, e.pos.y - @mouse_pos.y

      selected = @state.selected_objects

      if @control_points.index(selected[0]) != nil
        # we're resizing an object by dragging the control point
        
        current_object = selected[0].parent
        cp = @rect_hash[selected[0]]
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
        update_control_points(current_object.bounding_rect)
      else
        # we only draw control points if there is only one object selected
        # todo: draw control points over the total bounding rect of selected objects
				if selected.length == 1
					update_control_points(selected[0].bounding_rect) 
					selected[0].controller.object_selected(selected[0]) #todo a bit silly
				end
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
    end
  end

  def update_control_points(br)
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
    @state.prepare_object_creation(RectangleController.new(self))
  end
  
  def insert_math()
    @state.prepare_object_creation(MathController.new(self))
  end

  def update_text(text)
		if @state.creating?
			@state.controller.update_text(text)
		else
			@state.selected_objects[0].controller.update_text(text)
		end
  end

  def create_control_points()
    if @state.selected_objects.length == 1
      o = @state.selected_objects[0]
      
      @control_points.each { |c| c.hide() }
      @control_points = []
      NumControlPoints.times {
        rect = ControlPoint.new(Qt::Rect.new(0, 0, 10, 10), @canvas, o)
        rect.z = 1 # control points go on top of object
        rect.show()
        @control_points << rect
      }

      $log.info "blah #{o.class}"
      update_control_points(o.bounding_rect)
    else
      @control_points.each { |c| c.hide() }
      @control_points = []
    end
  end

  def setText(text)
    @text_box.text = text
  end

  def show_text_panel()
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

$log = Logger.new("whiteboard.log", 5, 10*1024)
$log.level = Logger::DEBUG
a = Qt::Application.new(ARGV)
w = WhiteboardMainWindow.new()
w.resize(450, 300)
w.show()
a.setMainWidget(w)
#Qt::Internal::setDebug Qt::QtDebugChannel::QTDB_GC
a.exec
