#!/usr/bin/env ruby -w

require 'whiteboard'
require 'Qt'

$user_id = ARGV[0] || 'magee'
$port = ARGV[1] || 2626
$host = "#{$port}"

a = Qt::Application.new(ARGV)
w = WhiteboardMainWindow.new()
w.resize(450, 300)
w.show()
a.setMainWidget(w)
#Qt::Internal::setDebug Qt::QtDebugChannel::QTDB_GC
a.exec()

