#!/usr/bin/env ruby -w

require 'whiteboard'
require 'test/unit'

$a = Qt::Application.new([]) if not defined? ($a)

class TestLine < Test::Unit::TestCase
	def test_line()
		w = WhiteboardMainWidget.new(nil)
		w.insert_line()
		assert_equal(true, w.state.creating?)
		w.left_mouse_press(10, 10)
		w.left_mouse_move(30, 30)
		w.left_mouse_release(30, 30)
		assert_equal(1, w.state.objects.length)
		assert_equal(true, w.state.objects[0].is_a?(WhiteboardLine))
		assert_equal(Qt::Point.new(10, 10), w.state.objects[0].start_point)
		assert_equal(Qt::Point.new(30, 30), w.state.objects[0].end_point)
		
		# now do another line where the start point is to the bottom-right	
		w.insert_line()
		assert_equal(true, w.state.creating?)
		w.left_mouse_press(50, 50)
		w.left_mouse_move(30, 30)
		w.left_mouse_release(30, 30)
		assert_equal(2, w.state.objects.length)
		assert_equal(true, w.state.objects[1].is_a?(WhiteboardLine))
		assert_equal(Qt::Point.new(50, 50), w.state.objects[1].start_point)
		assert_equal(Qt::Point.new(30, 30), w.state.objects[1].end_point)
	end

	def test_resize_line()
		#line in / direction
		l = WhiteboardLine.new(nil)
		l.set_points(50, 50, 100, 0)
		assert_equal(50, l.width())
		assert_equal(50, l.height())
		l.set_size(100, 100)
		assert_equal(50, l.x())
		assert_equal(0, l.y())
		assert_equal(50, l.start_point.x)
		assert_equal(100, l.start_point.y)
		assert_equal(150, l.end_point.x)
		assert_equal(0, l.end_point.y)

		#line in / direction, opposite start/endpoints
		l = WhiteboardLine.new(nil)
		l.set_points(100, 0, 50, 50)
		assert_equal(50, l.width())
		assert_equal(50, l.height())
		l.set_size(100, 100)
		assert_equal(50, l.x())
		assert_equal(0, l.y())
		assert_equal(50, l.end_point.x)
		assert_equal(100, l.end_point.y)
		assert_equal(150, l.start_point.x)
		assert_equal(0, l.start_point.y)

		#line in \ direction
		l = WhiteboardLine.new(nil)
		l.set_points(50, 50, 100, 100)
		assert_equal(50, l.width())
		assert_equal(50, l.height())
		l.set_size(100, 100)
		assert_equal(50, l.start_point.x)
		assert_equal(50, l.start_point.y)
		assert_equal(150, l.end_point.x)
		assert_equal(150, l.end_point.y)
	end

	def test_move_line()
		w = WhiteboardMainWidget.new(nil)
		w.insert_line()
		w.left_mouse_press(50, 50)
		w.left_mouse_move(70, 30)
		w.left_mouse_release(70, 30)
		
		w.left_mouse_press(70, 30)
		assert_equal(1, w.state.selected_objects.length)
	end
end
