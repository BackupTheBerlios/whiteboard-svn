require 'Qt'

class ObjectPopupMenu < Qt::PopupMenu
	slots 'properties_activated()', 'properties_changed(QString*)'
	signals 'properties_changed(QString*)'

	def initialize(object_selected, parent = nil)
		super(parent)
		@object_selected = object_selected

		insert_item("&Properties...", self, SLOT('properties_activated()'))
	end

	def properties_activated()
		f = ObjectPropertiesForm.new(@object_selected)
		connect(f, SIGNAL('updated(QString*)'), SLOT('properties_changed(QString*)'))
		f.exec()
	end

	def properties_changed(s)
		emit properties_changed(s)
	end
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
		@object.update_properties()
		close()
		emit updated(@object.whiteboard_object_id)
	end

	def cancel_clicked()
		close()
	end
end
