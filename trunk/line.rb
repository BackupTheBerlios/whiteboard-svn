require 'object'

class Qt::CanvasLine
	attr_reader :associated_object
	attr_writer :associated_object
end

class WhiteboardLine < WhiteboardObject
	# Although it's a bit inefficient, we derive
	# line from rectangle because the apis for the Qt
	# rectangle class are much more convenient to use
	# than the ones for the line class.  So we just
	# have a hidden rectangle and sync the line to its
	# corners.

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
	
	def move(x, y) 
		if @line.start_point.x < @line.end_point.x
			@line.set_points(x, y, x + width(), y + height)
		else
			@line.set_points(x + width(), y + height(), x, y)
		end
		update_arrow()
	end

	def move_by(dx, dy) 
		move(x() + dx, y() + dy)
	end
	
	def set_size(x, y) 
		if @line.start_point.x < @line.end_point.x
			@line.set_points(@line.start_point.x, @line.start_point.y, 
				@line.start_point.x + x, @line.start_point.y + y)
		else
			@line.set_points(@line.start_point.x + x, @line.start_point.y + y,
				@line.start_point.x, @line.start_point.y)
		end
	end
	def width() (@line.end_point.x - @line.start_point.x).abs end
	def height() (@line.end_point.y - @line.start_point.y).abs end
	def hide() @line.hide() end
	def bounding_rect() #@line.bounding_rect end
		Qt::Rect.new(@line.start_point, @line.end_point)
	end
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
