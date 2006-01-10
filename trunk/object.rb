require 'object_properties'
require 'Qt'

class Qt::Color
	def to_yaml_properties()
		@r, @g, @b = red, green, blue
		%w{ @r @g @b }
	end

	def from_yaml_object!()
		puts "from yaml object #{@r} #{@g} #{@b}"
		puts "#{@r} is a #{@r.class.to_s}"
		#setRgb(@r.to_i, @g.to_i, @b.to_i)
		puts "from yaml object"
	end
end

class WhiteboardObject < Qt::Object
  attr_reader :canvas_items, :controller, :whiteboard_object_id, :line_colour, :line_width, :fill_colour
	attr_writer :line_colour, :line_width, :fill_colour, :whiteboard_object_id
		# hack whiteboard-object-id shouldn't be public writable
	@@num_objects = 0

  def initialize(main_widget)
		super(nil)
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

	def to_yaml_properties()
		%w{ @whiteboard_object_id @fill_colour_r @fill_colour_g @fill_colour_b @line_colour_r @line_colour_g @line_colour_b 
			@line_width }
	end

	def to_yaml_object()
		@fill_colour_r, @fill_colour_g, @fill_colour_b = @fill_colour.red, @fill_colour.green, @fill_colour.blue
		@line_colour_r, @line_colour_g, @line_colour_b = @line_colour.red, @line_colour.green, @line_colour.blue
		self
	end

	def from_yaml_object()
		@fill_colour = Qt::Color.new(@fill_colour_r, @fill_colour_g, @fill_colour_b)
		@line_colour = Qt::Color.new(@line_colour_r, @line_colour_g, @line_colour_b)
		self
	end

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
	signals 'updated(QString*)'

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
		emit updated(@object.whiteboard_object_id)
	end

	def cancel_clicked()
		close()
	end
end

