require 'object_properties'

class WhiteboardObject
  attr_reader :canvas_items, :controller, :whiteboard_object_id, :line_colour, :line_width, :fill_colour
	attr_writer :line_colour, :line_width, :fill_colour
	@@num_objects = 0

  def initialize(main_widget)
		set_main_widget(main_widget)
		@whiteboard_object_id = "#{$user_id}:#{@@num_objects}"
		@@num_objects += 1

		@line_colour = Qt::black
		@line_width = 1
		@fill_colour = Qt::white
  end

	def set_main_widget(main_widget)
    @main_widget = main_widget
    @canvas = main_widget.canvas
		@canvas_view = main_widget.canvas_view
		@network_interface = main_widget.network_interface
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

class ObjectPropertiesForm < ObjectPropertiesUI
	slots 'ok_clicked()', 'cancel_clicked()'

	@@colours = [
		["Black", Qt::black],
		["Blue", Qt::blue],
		["Green", Qt::green],
		["Red", Qt::red],
		["Yellow", Qt::yellow]
	]

	def initialize(object)
		@object = object
		super()
	
		[@line_colour, @fill_colour].each do |c|
			@@colours.each do |col|
				c.insert_item(col[0])
			end
		end

		1.upto(10) { |w| @line_width.insert_item(w.to_s) }

		connect(ok_button, SIGNAL('clicked()'), SLOT('ok_clicked()'))
		connect(cancel_button, SIGNAL('clicked()'), SLOT('cancel_clicked()'))
	end

	def ok_clicked()
		@object.fill_colour = @@colours[@fill_colour.current_item][1]
		@object.line_colour = @@colours[@line_colour.current_item][1]
		@object.line_width = @line_width.current_item + 1
		@object.update()
		close()
	end

	def cancel_clicked()
		close()
	end
end
