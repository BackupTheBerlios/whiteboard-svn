class WhiteboardObject
  attr_reader :canvas_items, :controller, :whiteboard_object_id
	@@num_objects = 0

	def set_main_widget(main_widget)
    @canvas = main_widget.canvas
		@canvas_view = main_widget.canvas_view
    @main_widget = main_widget
		@network_interface = main_widget.network_interface
	end

  def initialize(main_widget)
		set_main_widget(main_widget)
		@whiteboard_object_id = "#{$user_id}:#{@@num_objects}"
		puts "object id is #{@whiteboard_object_id}"
		@@num_objects += 1
  end

  def mousePress(e) end
  def mouseMove(e) end
  def mouseRelease(e) end
  def create(p) end
  def select_object() end

	def to_s()
		YAML.dump(to_yaml_object()).to_s
	end
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

