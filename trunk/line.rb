require 'object'

class Qt::CanvasLine
	attr_reader :associated_object
	attr_writer :associated_object
end

class WhiteboardLine < WhiteboardRectangle
	# Although it's a bit inefficient, we derive
	# line from rectangle because the apis for the Qt
	# rectangle class are much more convenient to use
	# than the ones for the line class.  So we just
	# have a hidden rectangle and sync the line to its
	# corners.

	def initialize(mainWidget)
		super(mainWidget)
		@line = Qt::CanvasLine.new(@canvas)
		@line.associated_object = self
		@canvas_items = [@line]
	end

	def sync_to_rect()
		@line.set_points(@rect.x, @rect.y, @rect.x + @rect.width, @rect.y + @rect.height)
	end

	def mousePress(e)
		super(e)
		@rect.hide()
		@line.show()
		sync_to_rect()
	end

	def mouseMove(e)
		super(e)
		sync_to_rect()
	end

	def move(x, y)
		super(x, y)
		sync_to_rect()
	end

	def move_by(x, y)
		super(x, y)
		sync_to_rect()
	end

	def set_size(x, y)
		super(x, y)
		sync_to_rect()
	end
	
	def to_yaml_object()
		LineYamlObject.new(@whiteboard_object_id, @rect.x, @rect.y, @rect.width, @rect.height)
	end

	def from_yaml_object(y)
		@whiteboard_object_id = y.whiteboard_object_id
		@rect.move(y.x, y.y)
		@rect.set_size(y.width, y.height)
		@rect.hide()
		@line.show()
		sync_to_rect()
		self
	end
end

class LineYamlObject
	attr_reader :whiteboard_object_id, :x, :y, :width, :height

	def initialize(whiteboard_object_id, x, y, width, height)
		@whiteboard_object_id, @x, @y, @width, @height = whiteboard_object_id, x, y, width, height
	end
	
	def to_yaml_properties()
		%w{ @whiteboard_object_id @x @y @width @height }
	end

	def to_actual_object(main_widget)
		WhiteboardLine.new(main_widget).from_yaml_object(self)
	end
end
