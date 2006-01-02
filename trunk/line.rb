require 'object'

class Qt::CanvasLine
	attr_reader :associated_object
	attr_writer :associated_object

	def set_size(dx, dy)
		setPoints(startPoint.x, startPoint.y, startPoint.x + dx, startPoint.y + dy)
	end
end

class LineController < WhiteboardObjectController
  def initialize(mainWidget)
    super(mainWidget)
  end

  def mousePress(e)
    @point1 = Qt::Point.new(e.x, e.y)
    @line = WhiteboardLine.new(@canvas, e, self)
  end

  def mouseMove(e)
		@line.set_points(@point1.x, @point1.y, e.pos.x, e.pos.y)
    @canvas.update()
  end

  def mouseRelease(e)
    @mainWidget.create_object(@line)
  end
end

class WhiteboardLine < WhiteboardObject
	def initialize(canvas, e, controller)
		@line = Qt::CanvasLine.new(canvas)
		@line.set_points(e.pos.x, e.pos.y, e.pos.x + 1, e.pos.y + 1)
		@line.show()
		@line.associated_object = self
		@canvas_items = [@line]
		@controller = controller

		canvas.update()
	end

	def set_points(*args) @line.set_points(*args) end

	def move(x, y) @line.move(x, y) end
	def move_by(x, y) @line.move_by(x, y) end
	def set_size(x, y) @line.set_size(x, y) end
	def width() (@line.endPoint.x - @line.startPoint.x).abs end
	def height() (@line.endPoint.y - @line.startPoint.y).abs end
	def bounding_rect() @line.bounding_rect end
end

