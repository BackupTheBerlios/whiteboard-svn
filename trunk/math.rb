require 'object'

class Qt::CanvasSprite
	attr_reader :associated_object
	attr_writer :associated_object
end

class WhiteboardMathObject < WhiteboardObject
	attr_reader :text
	attr_writer :point #hack, should be private
	signals 'started_editing(QString*)', 'finished_editing()'

  def initialize(main_widget = nil)
    super(main_widget)
		@sprite = nil
  end

  def mousePress(e)
		@point = Qt::Point.new(e.x, e.y)
		emit started_editing('')
  end	

	#hack (should be private?)
	def set_text(text)
		@text = text

		system("kopete_latexconvert.sh '" + text + "'")
		image = Qt::Image.new("out.png")
		pix = Qt::CanvasPixmapArray.new([Qt::Pixmap.new(image)])
		@sprite = Qt::CanvasSprite.new(pix, @canvas) 
		@sprite.associated_object = self
		@sprite.move(@point.x, @point.y)
		@sprite.show()

		@canvas_items = [@sprite]

		# we put the pixmap onto an array that will be kept, otherwise
		# we get a segfault on garbage collection
		$pixmaps ||= []
		$pixmaps << pix
	end

	public
  def update_text(text)
		emit finished_editing()
		if @sprite != nil
			@sprite.hide()
			@sprite = nil
			set_text(text)
		else
			set_text(text)
			@main_widget.create_object(self)
		end

		@canvas.update()
  end

	def to_yaml_properties()
		super() + %w{ @x @y @text }
	end

	def to_yaml_object()
		@x, @y = @sprite.x, @sprite.y
		self
	end

	def from_yaml_object(main_widget)
		w = WhiteboardMathObject.new(main_widget)
		w.whiteboard_object_id = @whiteboard_object_id
		w.point = Qt::Point.new(@x, @y)
		w.set_text(@text)
		w
	end

  def select_object()
		emit started_editing(@text)
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
