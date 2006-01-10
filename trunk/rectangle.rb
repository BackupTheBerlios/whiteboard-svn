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

	def setup()
		@rect = Qt::CanvasRectangle.new(0, 0, 0, 0, @canvas)
		@rect.associated_object = self
		@canvas_items = [@rect]
	end

  def initialize(main_widget)
    super(main_widget)
		setup()
  end

  def mousePress(e)
    @point1 = Qt::Point.new(e.x, e.y)
		@rect.move(e.x, e.y)
		@rect.set_size(1, 1)
		@rect.show()
		update_properties() #hack?
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

	def to_yaml_properties()
		super() + %w{ @x @y @width @height }
	end

	def to_yaml_object()
		super()
		@x, @y, @width, @height = @rect.x, @rect.y, @rect.width, @rect.height
		self 
	end

	def from_yaml_object(main_widget)
		super()
		set_main_widget(main_widget)
		setup()
		@rect.move(@x, @y)
		@rect.set_size(@width, @height)
		update_properties()
		@rect.show()
		self
	end

	def update_properties()
		@rect.set_pen(Qt::Pen.new(@line_colour, @line_width))
		@rect.set_brush(Qt::Brush.new(@fill_colour))
		@canvas.update()
	end

	def x() @rect.x end
	def y() @rect.y end
	def move(x, y) @rect.move(x, y) end
	def move_by(x, y) @rect.move_by(x, y) end
	def set_size(x, y) @rect.set_size(x, y) end
	def width() @rect.width end
	def height() @rect.height end
	def bounding_rect() @rect.rect end
end
