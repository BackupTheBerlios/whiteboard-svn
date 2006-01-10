File.open('object_properties.rb', 'r') do |f|
	h = {
		"fill_colour" => "ColourButton",
		"line_colour" => "ColourButton"
	}

	a = f.readlines()
	a.each do |l|
		m = l.match(/(\w+)\s*=\s*([\w:]+).new(.*)/)
		if m != nil
			name, type = m[1], m[2]
			l.sub!(type, h[name]) if h[name] != nil
		end
		puts l
		puts "require 'object'" if l.chomp == "require 'Qt'"
	end
end
