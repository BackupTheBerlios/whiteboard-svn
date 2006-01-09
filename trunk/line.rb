require 'object'

class Qt::CanvasLine
	attr_reader :associated_object
	attr_writer :associated_object
end

class WhiteboardLine < WhiteboardObject
	def initialize(mainWidget, is_arrow = false)
		super(mainWidget)
		@line = Qt::CanvasLine.new(@canvas)
		@line.associated_object = self
		@canvas_items = [@line]
		@is_arrow = is_arrow
		@arrow1, @arrow2 = nil, nil
	end

	def mousePress(e)
		@point1 = Qt::Point.new(e.x, e.y)
		@line.set_points(@point1.x, @point1.y, @point1.x + 1, @point1.y + 1)
		@line.show()
	end

	def mouseMove(e)
		@line.set_points(@point1.x, @point1.y, e.x, e.y)
		update_arrow()
		@canvas.update()
	end
  
	def mouseRelease(e)
    @main_widget.create_object(self)
  end

	def to_yaml_object()
		LineYamlObject.new(@whiteboard_object_id, @line.start_point.x, @line.start_point.y,
			@line.end_point.x, @line.end_point.y, @is_arrow)
	end

	def from_yaml_object(y)
		@whiteboard_object_id = y.whiteboard_object_id
		@line.set_points(y.x1, y.x2, y.y1, y.y2)
		@line.show()
		@is_arrow = y.is_arrow
		update_arrow()
		self
	end
	
	def update_arrow()
		if @is_arrow
			angle = Math.atan2(@line.end_point.y - @line.start_point.y, 
				@line.end_point.x - @line.start_point.x)
			if @arrow1 == nil
				@arrow1 = Qt::CanvasLine.new(@canvas)
				@arrow2 = Qt::CanvasLine.new(@canvas)
				@arrow1.show()
				@arrow2.show()
				@canvas_items = [@line, @arrow1, @arrow2]
			end

			m = Qt::WMatrix.new()
			m.translate(@line.end_point.x(), @line.end_point.y())
			m.rotate((angle + Math::PI / 2) * 180 / Math::PI)

			p1 = m.map(Qt::Point.new( 0,   0))
			p2 = m.map(Qt::Point.new( 5,  10))
			p3 = m.map(Qt::Point.new(-5,  10))

			@arrow1.set_points(p1.x, p1.y, p2.x, p2.y)
			@arrow2.set_points(p1.x, p1.y, p3.x, p3.y)
			@canvas.update()
		end
	end
	
	def x() [@line.start_point.x, @line.end_point.x].min end
	def y() [@line.start_point.y, @line.end_point.y].min end
	
	def move_by(dx, dy) 
		@line.set_points(@line.start_point.x + dx, @line.start_point.y + dy,
			@line.end_point.x + dx, @line.end_point.y + dy)
		update_arrow()
	end
	
	def move(x, y) 
		move_by(x - x(), y - y())
	end
	
	def set_size(x, y) 
		x1, y1, x2, y2 = @line.start_point.x, @line.start_point.y, @line.end_point.x, @line.end_point.y
		if x1 > x2
			x1 = x() + x
		else
			x2 = x() + x
		end
		if y1 > y2
			y1 = y() + y
		else
			y2 = y() + y
		end

		@line.set_points(x1, y1, x2, y2)
	end

	def width() (@line.end_point.x - @line.start_point.x).abs end
	def height() (@line.end_point.y - @line.start_point.y).abs end
	def bounding_rect() Qt::Rect.new(x(), y(), width(), height()) end
	def start_point() @line.start_point end
	def end_point() @line.end_point end

	def set_points(x1, y1, x2, y2) @line.set_points(x1, y1, x2, y2) end
end

class LineYamlObject
	attr_reader :whiteboard_object_id, :x1, :y1, :x2, :y2, :is_arrow

	def initialize(whiteboard_object_id, x1, x2, y1, y2, is_arrow)
		@whiteboard_object_id, @x1, @x2, @y1, @y2, @is_arrow = whiteboard_object_id, x1, x2, y1, y2, is_arrow
	end
	
	def to_yaml_properties()
		%w{ @whiteboard_object_id @x1 @x2 @y1 @y2 @is_arrow }
	end

	def to_actual_object(main_widget)
		WhiteboardLine.new(main_widget).from_yaml_object(self)
	end
end
