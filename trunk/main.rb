#!/usr/bin/env ruby -w

# set stderr to stdout so the stupid yaml errors
# go to the same place as everything else so we 
# can pipe them out
$stderr = $stdout

require 'whiteboard'
require 'Qt'

$user_id = ARGV[0] || 'magee'
$port = ARGV[1] || 2626
$host = "#{$port}"

a = Qt::Application.new(ARGV)
w = WhiteboardMainWindow.new($port)
w.resize(450, 300)
w.show()
a.setMainWidget(w)
#Qt::Internal::setDebug Qt::QtDebugChannel::QTDB_GC
a.exec()

