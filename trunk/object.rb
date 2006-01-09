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
		if main_widget != nil
			@canvas = main_widget.canvas
			@canvas_view = main_widget.canvas_view
			@network_interface = main_widget.network_interface
		end
	end

  def mousePress(e) end
  def mouseMove(e) end
  def mouseRelease(e) end
  def create(p) end
  def select_object() end
	def hide() @canvas_items.each { |i| i.hide() } end

	def to_s()
		YAML.dump(to_yaml_object()).to_s
	end

	def update() end
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

class ColourButton < Qt::PushButton
	attr_reader :colour

	slots 'clicked()'

	def initialize(parent, name, colour = nil)
		super(parent, name)
		@colour = colour
		set_palette_background_color(@colour) if colour != nil
		connect(self, SIGNAL('clicked()'), SLOT('clicked()'))
	end

	def clicked()
		@colour = Qt::ColorDialog.get_color()
		set_palette_background_color(colour)
	end

	def colour=(colour)
		@colour = colour
		set_palette_background_color(colour)
	end
end

class Qt::Color
	def dup()
		Qt::Color.new(red, green, blue)
	end
end

class ObjectPropertiesForm < ObjectPropertiesUI
	slots 'ok_clicked()', 'cancel_clicked()', 'line_colour_clicked()', 'fill_colour_clicked()'

	@@colours = []

	def initialize(object)
		@object = object
		super()
	
		1.upto(10) { |w| @line_width.insert_item(w.to_s) }

		@fill_colour.colour = @object.fill_colour
		@line_colour.colour = @object.line_colour

		connect(ok_button, SIGNAL('clicked()'), SLOT('ok_clicked()'))
		connect(cancel_button, SIGNAL('clicked()'), SLOT('cancel_clicked()'))
	end

	def ok_clicked()
		@object.fill_colour = @fill_colour.colour.dup()
		@object.line_colour = @line_colour.colour.dup()
		@object.line_width = @line_width.current_item + 1
		@object.update()
		close()
	end

	def cancel_clicked()
		close()
	end
end

