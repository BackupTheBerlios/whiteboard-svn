$VERBOSE = true; $:.unshift File.dirname($0)
require 'object'

class Qt::CanvasRectangle
	attr_reader :associated_object
	attr_writer :associated_object
end

class RectangleController < WhiteboardObjectController
  def initialize(mainWidget)
    super(mainWidget)
  end

  def mousePress(e)
    @point1 = Qt::Point.new(e.x, e.y)
    @rect = WhiteboardRectangle.new(@canvas, e, self)
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
    @mainWidget.create_object(@rect)
  end
end

class WhiteboardRectangle < WhiteboardObject
	def initialize(canvas, e, controller)
		@rect = Qt::CanvasRectangle.new(e.pos.x, e.pos.y, 1, 1, canvas)
		@rect.show()
		@rect.associated_object = self
		@canvas_items = [@rect]
		@controller = controller
	end

	def x() @rect.x end
	def y() @rect.y end
	def move(x, y) @rect.move(x, y) end
	def move_by(x, y) @rect.move_by(x, y) end
	def set_size(x, y) @rect.setSize(x, y) end
	def width() @rect.width end
	def height() @rect.height end

	# todo work out between rect/bounding_rect
	def bounding_rect() @rect.rect end
end
