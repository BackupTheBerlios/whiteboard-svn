$VERBOSE = true; $:.unshift File.dirname($0)
require 'object'

class Qt::Rect
	def to_s
		"(#{x}, #{y}), (#{x + width}, #{y + height})"
	end
end

class Qt::CanvasRectangle
	attr_reader :associated_object
	attr_writer :associated_object
end

class WhiteboardRectangle < WhiteboardObject
	attr_reader :rect

  def initialize(main_widget)
    super(main_widget)
		@rect = Qt::CanvasRectangle.new(0, 0, 0, 0, @canvas)
		@rect.associated_object = self
		@canvas_items = [@rect]
  end

  def mousePress(e)
    @point1 = Qt::Point.new(e.x, e.y)
		@rect.move(e.x, e.y)
		@rect.set_size(1, 1)
		@rect.show()
	end

  def mouseMove(e)
    point2 = Qt::Point.new(e.pos.x, e.pos.y)
    points = (@point1.x < point2.x) ? [@point1, point2] : [point2, @point1]
    @rect.move(points[0].x, points[0].y)
    size = points[1] - points[0]
    @rect.set_size(size.x, size.y)
    @canvas.update()
  end

  def mouseRelease(e)
    @main_widget.create_object(self)
  end

	def to_yaml_object()
		RectangleYamlObject.new(@whiteboard_object_id, @rect.x, @rect.y, @rect.width, @rect.height)
	end

	def from_yaml_object(y)
		@whiteboard_object_id = y.whiteboard_object_id
		@rect.move(y.x, y.y)
		@rect.set_size(y.width, y.height)
		@rect.show()
		self
	end

	def update() # temp
		@rect.set_pen(Qt::Pen.new(@line_colour, @line_width))
		@rect.set_brush(Qt::Brush.new(@fill_colour))
		@canvas.update()
	end

	def x() @rect.x end
	def y() @rect.y end
	def move(x, y) @rect.move(x, y) end
	def move_by(x, y) @rect.move_by(x, y) end
	def set_size(x, y) @rect.setSize(x, y) end
	def width() @rect.width end
	def height() @rect.height end
	def hide() @rect.hide() end
	# todo work out between rect/bounding_rect
	def bounding_rect() @rect.rect end
end

class RectangleYamlObject
	attr_reader :whiteboard_object_id, :x, :y, :width, :height

	def initialize(whiteboard_object_id, x, y, width, height)
		@whiteboard_object_id, @x, @y, @width, @height = whiteboard_object_id, x, y, width, height
	end
	
	def to_yaml_properties()
		%w{ @whiteboard_object_id @x @y @width @height }
	end

	def to_actual_object(main_widget)
		WhiteboardRectangle.new(main_widget).from_yaml_object(self)
	end
end
