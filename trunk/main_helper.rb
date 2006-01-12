require 'whiteboard'

def start_double()
	w = WhiteboardMainWindow.new("magee1", 2627)
	w.resize(450, 300)
	w.show()
	w2 = WhiteboardMainWindow.new("magee2", 2628)
	w2.resize(450, 300)
	w2.show()
	w.start_server()
	w2.start_client("localhost", 2627)
	[w, w2]
end
