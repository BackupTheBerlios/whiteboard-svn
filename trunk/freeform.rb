require 'object'

class Point
	attr_reader :x, :y
	attr_writer :x, :y

	def initialize(x, y)
		@x, @y = x, y
	end

	def to_yaml_properties() %w{ @x @y } end
end

class WhiteboardFreeForm < WhiteboardObject
	def initialize(main_widget)
		super(main_widget)
	end

	def add_point(x, y)
		p = Qt::CanvasLine.new(@canvas)
		p.set_points(@last_point.x, @last_point.y, x, y)
		p.associated_object = self
		p.show()
		@canvas_items << p

		@x = x if x < @x
		@y = y if y < @y
		@right = x if x > @right
		@bottom = y if y > @bottom
		@width = @right - @x
		@height = @bottom - @y

		@last_point = Qt::Point.new(x, y)
	end

	def mousePress(e)
		@x, @y = e.x, e.y
		@right, @bottom = e.x, e.y
		@last_point = Qt::Point.new(e.x, e.y)
		@canvas_items = []
		add_point(e.x, e.y)
	end

	def mouseMove(e)
		add_point(e.x, e.y)
	end
  
	def mouseRelease(e)
    @main_widget.create_object(self)
  end

	def to_yaml_properties()
		super() + %w{ @points }
	end

	def to_yaml_object()
		@points = @canvas_items.map { |i| Point.new(i.end_point.x, i.end_point.y) }
		self
	end

	def from_yaml_object(main_widget)
		set_main_widget(main_widget)
		@x, @y = @points[0].x, @points[0].y
		@right, @bottom = @x, @y
		@last_point = Qt::Point.new(@x, @y)
		@canvas_items = []
		@points.each { |p| add_point(p.x, p.y) }
		self
	end
	
	def update_properties()
		@canvas_items.each { |c| c.set_pen(Qt::Pen.new(@line_colour, @line_width)) }
		@canvas.update()
	end

	attr_reader :x, :y, :width, :height
	
	def move_by(dx, dy) 
		@x += dx
		@y += dy
		@canvas_items.each { |i| i.move_by(dx, dy) }
	end
	
	def move(x, y) 
		move_by(x - x(), y - y())
	end
	
	def set_size(x, y) 
	end

	def bounding_rect() Qt::Rect.new(x(), y(), width(), height()) end
end
