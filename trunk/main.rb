#!/usr/bin/env ruby -w

# set stderr to stdout so the stupid yaml errors
# go to the same place as everything else so we 
# can pipe them out
$stderr = $stdout

require 'whiteboard'
require 'Qt'
require 'main_helper'

a = Qt::Application.new(ARGV)

if ARGV[0] == "double"
	#Qt::Internal::setDebug Qt::QtDebugChannel::QTDB_GC
	w, w2 = start_double()
else
	user_id = ARGV[0] || 'magee'
	port = ARGV[1] || 2626

	w = WhiteboardMainWindow.new(user_id, port)
	w.resize(450, 300)
	w.show()
#Qt::Internal::setDebug Qt::QtDebugChannel::QTDB_GC
end

a.set_main_widget(w)
a.exec()
