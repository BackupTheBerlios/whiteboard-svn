require 'object'
require 'Qt'

class WhiteboardImageObject < WhiteboardObject
	def initialize(main_widget)
		super(main_widget)
		name = Qt::FileDialog.get_open_file_name(
			"~/", 
			"Image files (*.png *.jpg *.jpeg *.bmp)",
			@main_widget,
			"open file dialog",
			"Please choose an image"
		)
		
		pix = Qt::CanvasPixmapArray.new([Qt::Pixmap.new(name)])
		$pixmaps ||= []
		$pixmaps << pix
		@sprite = Qt::CanvasSprite.new(pix, @canvas)
		@sprite.associated_object = self
		@canvas_items = [@sprite]
	end

	def mousePress(e)
		@sprite.move(e.x, e.y)
		@sprite.show()
    @main_widget.create_object(self)
	end

	def to_yaml_object()
		LineYamlObject.new("1", 1, 2, 3, 4, false)
	end

	def from_yaml_object(y)
	end
	
	def x() @sprite.x end
	def y() @sprite.y end	
	def move(x, y) @sprite.move(x, y) end
	def move_by(x, y) @sprite.move_by(x, y) end
	def set_size(x, y) end
	def width() @sprite.width end
	def height() @sprite.height end
	def bounding_rect() @sprite.bounding_rect end
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

