class WhiteboardObjectController
  signals 'itemCreated(WhiteboardObject)', 'itemModified(WhiteboardObject)'

  def initialize(mainWidget)
    @canvas = mainWidget.canvas
    @mainWidget = mainWidget
  end

  def mousePress(e) end
  def mouseMove(e) end
  def mouseRelease(e) end
  def create(p) end
  def object_selected(o) end
end

class WhiteboardObject
  attr_reader :canvas_items, :controller
end

class WhiteboardCompositeObject
	def initialize(objects)
		@objects = objects
		@orig_rects = {}
		@objects.each { |o| @orig_rects[o] = o.bounding_rect }
		@rect = total_bounding_rect(objects.map { |o| o.bounding_rect })
		@orig_rect = Qt::Rect.new(@rect.top_left, @rect.size)
	end

	def set_size(width, height)
		@objects.each do |o|
			s = @orig_rects[o]
			o.move(@rect.x + (s.x - @orig_rect.x) * width / @orig_rect.width, 
				@rect.y + (s.y - @orig_rect.y) * height / @orig_rect.height)
			o.set_size(s.width * width / @orig_rect.width, s.height * height / @orig_rect.height)
		end
		@rect.set_size(Qt::Size.new(width, height))
	end

	def move_by(x, y)
		@objects.each { |o| o.move_by(x, y) }
		@rect.move_by(x, y)
	end

	def width() @rect.width end
	def height() @rect.height end
	def bounding_rect() @rect end
end

