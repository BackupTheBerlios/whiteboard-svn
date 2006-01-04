require 'object'

class Qt::CanvasSprite
	attr_reader :associated_object
	attr_writer :associated_object
end

class WhiteboardMathObject < WhiteboardObject
####HACK this is awfully written!!!!
	attr_reader :text

  def initialize(mainWidget)
    super(mainWidget)
		@canvasObject = nil
  end

  def mousePress(e)
    @point = Qt::Point.new(e.pos.x - @mainWidget.canvasView.x, e.pos.y - @mainWidget.canvasView.y)
    @mainWidget.show_text_panel()
  end	

  def update_text(text)
    @mainWidget.hide_text_panel()
		if @canvasObject == nil
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
			@mainWidget.create_object(self)
		else
			@canvasObject.text = text
			@canvas.update()
		end
  end

	def to_yaml_object()
		MathYamlObject.new(@sprite.x, @sprite.y, @text)
	end

	def from_yaml_object(o)
		@point = Qt::Point.new(o.x, o.y)
		@text = o.text

		system("kopete_latexconvert.sh '" + @text + "'")
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
		self
	end

	def text=(text)
		@text = text
    system("kopete_latexconvert.sh '" + text + "'")
    image = Qt::Image.new("out.png")
    pix = Qt::CanvasPixmapArray.new([Qt::Pixmap.new(image)])
    @sprite.set_sequence(pix)
		
		@canvas_items = [@sprite]
		$pixmaps ||= []
		$pixmaps << pix
	end

  def select_object()
    @mainWidget.show_text_panel(@text)
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

class MathYamlObject
	attr_reader :x, :y, :text

	def initialize(x, y, text)
		@x, @y, @text = x, y, text
	end
	
	def to_yaml_properties()
		%w{ @x @y @text }
	end

	def to_actual_object(main_widget)
		WhiteboardMathObject.new(main_widget).from_yaml_object(self)
	end
end
