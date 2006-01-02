require 'object'

class Qt::CanvasSprite
	attr_reader :associated_object
	attr_writer :associated_object
end

class WhiteboardMathObject < WhiteboardObject
	attr_reader :text

	def initialize(canvas, point, text, controller)
		@text = text
		@point = point
		@canvas = canvas

    system("kopete_latexconvert.sh '" + text + "'")
    image = Qt::Image.new("out.png")
    pix = Qt::CanvasPixmapArray.new([Qt::Pixmap.new(image)])
    @sprite = Qt::CanvasSprite.new(pix, canvas) 
		@sprite.associated_object = self
    @sprite.move(@point.x, @point.y)
    @sprite.show()

		@canvas_items = [@sprite]

		@controller = controller

    # we put the pixmap onto an array that will be kept, otherwise
    # we get a segfault on garbage collection
		$pixmaps ||= []
		$pixmaps << pix
	end

	def text=(text)
		@text = text
    system("kopete_latexconvert.sh '" + text + "'")
    image = Qt::Image.new("out.png")
    pix = Qt::CanvasPixmapArray.new([Qt::Pixmap.new(image)])
    @sprite.set_sequence(pix)
		
		@canvas_items = [@sprite]
		$pixmaps << pix
	end

	def move(x, y) @sprite.move(x, y) end
	def move_by(x, y) @sprite.move_by(x, y) end
	def set_size(x, y) end
	def width() @sprite.width end
	def height() @sprite.height end
	def bounding_rect() @sprite.bounding_rect end
end

class MathController < WhiteboardObjectController
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
			@canvasObject = WhiteboardMathObject.new(@canvas, @point, text, self)
			@mainWidget.create_object(@canvasObject)
		else
			@canvasObject.text = text
			@canvas.update()
		end
  end

  def object_selected(o)
    @mainWidget.show_text_panel(@canvasObject.text)
  end
end
