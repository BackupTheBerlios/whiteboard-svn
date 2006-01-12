#!/usr/bin/env ruby -w

require 'whiteboard'
require 'test/unit'

class TestRectangle < Test::Unit::TestCase
	def test_create_rect()
		w = WhiteboardMainWidget.new('blah', nil)
		w.prepare_object_creation(WhiteboardRectangle.new(w))
		assert_equal(true, w.state.creating?)
		w.left_mouse_press(10, 10)
		w.left_mouse_move(30, 30)
		w.left_mouse_release(30, 30)
		assert_equal(1, w.state.objects.length)
		assert_equal(true, w.state.objects[0].is_a?(WhiteboardRectangle))
		assert_rect_equal_wh(w.state.objects[0], 10, 10, 20, 20)
	end

	def test_create_rects()
		w = WhiteboardMainWidget.new('blah', nil)
		w.prepare_object_creation(WhiteboardRectangle.new(w))
		w.left_mouse_press(10, 10)
		w.left_mouse_release(10, 10)
		w.prepare_object_creation(WhiteboardRectangle.new(w))
		w.left_mouse_press(10, 10)
		w.left_mouse_release(10, 10)
		assert_equal(w.state.objects.length, 2)
		assert_equal(true, w.state.objects[0].is_a?(WhiteboardRectangle))
		assert_equal(true, w.state.objects[1].is_a?(WhiteboardRectangle))
	end

	def test_resize_rect()
		w = WhiteboardMainWidget.new('blah', nil)
		w.prepare_object_creation(WhiteboardRectangle.new(w))
		w.left_mouse_press(10, 10)
		w.left_mouse_move(30, 30)
		w.left_mouse_release(30, 30)

		## notice we have to move to the end point before we release
		## we should probably not have to do this
	
		w.left_mouse_press(30, 30)	
		w.left_mouse_release(30, 30)	
		assert_equal(1, w.state.selected_objects.length)
		assert_rect_equal_wh(w.state.objects[0], 10, 10, 20, 20)

		w.left_mouse_press(30, 30)
		assert_equal("Resizing", w.state.to_s)

		w.left_mouse_move(50, 30)
		w.left_mouse_release(50, 30)
		
		assert_rect_equal_wh(w.state.objects[0], 10, 10, 40, 20)
	end

	def test_total_bounding_rect()
		r1 = Qt::Rect.new(Qt::Point.new(10, 10), Qt::Point.new(30, 30))
		r2 = Qt::Rect.new(Qt::Point.new(50, 50), Qt::Point.new(70, 70))
		assert_rect_equal(total_bounding_rect([r1, r2]), 10, 10, 70, 70)
		assert_rect_equal(total_bounding_rect([r1]), 10, 10, 30, 30)
	end
end

class DummyRect < Qt::Rect
	def initialize(a, b, c, d) super(a, b, c, d) end
	def bounding_rect() Qt::Rect.new(top_left(), bottom_right()) end
	def move(x, y) move_top_left(Qt::Point.new(x, y)) end
	def set_size(w, h) 
		set_width(w)
		set_height(h)
	end
end
