#!/usr/bin/env ruby -w

require 'whiteboard'
require 'test/unit'

$a = Qt::Application.new([])

def assert_rect_equal_wh(o, x, y, width, height)
	assert_equal(x, o.x)
	assert_equal(y, o.y)
	assert_equal(width, o.width)
	assert_equal(height, o.height)
end

def assert_rect_equal(o, left, top, right, bottom)
	assert_equal(left, o.left)
	assert_equal(right, o.right)
	assert_equal(top, o.top)
	assert_equal(bottom, o.bottom)
end

class TestWhiteboard < Test::Unit::TestCase
	def test_default()
		w = WhiteboardMainWidget.new(nil)
		assert_equal("Default", w.state.to_s)
	end	

	def test_create_rect()
		w = WhiteboardMainWidget.new(nil)
		w.insert_rectangle()
		assert_equal(true, w.state.creating?)
		w.left_mouse_press(10, 10)
		w.left_mouse_move(30, 30)
		w.left_mouse_release(30, 30)
		assert_equal(1, w.state.objects.length)
		assert_equal(true, w.state.objects[0].is_a?(WhiteboardRectangle))
		assert_rect_equal_wh(w.state.objects[0], 10, 10, 20, 20)
	end

	def test_create_rects()
		w = WhiteboardMainWidget.new(nil)
		w.insert_rectangle()
		w.left_mouse_press(10, 10)
		w.left_mouse_release(10, 10)
		w.insert_rectangle()
		w.left_mouse_press(10, 10)
		w.left_mouse_release(10, 10)
		assert_equal(w.state.objects.length, 2)
		assert_equal(true, w.state.objects[0].is_a?(WhiteboardRectangle))
		assert_equal(true, w.state.objects[1].is_a?(WhiteboardRectangle))
	end

	def test_resize_rect()
		w = WhiteboardMainWidget.new(nil)
		w.insert_rectangle()
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

	def test_selection()
		w = WhiteboardMainWidget.new(nil)
		w.insert_rectangle()
		w.left_mouse_press(10, 10)
		w.left_mouse_move(30, 30)
		w.left_mouse_release(30, 30)

		w.insert_rectangle()
		w.left_mouse_press(50, 10)
		w.left_mouse_move(70, 30)
		w.left_mouse_release(70, 30)

		w.left_mouse_press(5, 5)
		assert_equal("Selecting", w.state.to_s)
		assert_equal(0, w.state.selected_objects.length)

		w.left_mouse_move(15, 15)
		assert_equal("Selecting", w.state.to_s)
		assert_equal(1, w.state.selected_objects.length)

		w.left_mouse_move(55, 15)
		assert_equal("Selecting", w.state.to_s)
		assert_equal(2, w.state.selected_objects.length)
	end

	def test_composite_object_single()
		r = DummyRect.new(10, 10, 20, 20)
		w = WhiteboardCompositeObject.new([r])
		assert_rect_equal_wh(w.bounding_rect, 10, 10, 20, 20)
		w.set_size(50, 50)
		assert_equal(50, r.width)
		assert_equal(50, r.height)
		w.set_size(70, 70)
		assert_equal(70, r.width)
		assert_equal(70, r.height)
	end

	def test_composite_object_multiple()
		r1 = DummyRect.new(10, 10, 20, 20)
		r2 = DummyRect.new(30, 10, 20, 20)
		w = WhiteboardCompositeObject.new([r1, r2])
		assert_rect_equal_wh(w.bounding_rect, 10, 10, 40, 20)
		w.set_size(80, 40)
		assert_rect_equal_wh(r1, 10, 10, 40, 40)
		assert_rect_equal_wh(r2, 50, 10, 40, 40)
		w.set_size(40, 20)
		assert_rect_equal_wh(r1, 10, 10, 20, 20)
		assert_rect_equal_wh(r2, 30, 10, 20, 20)
	end

	def test_composite_object_move()
		r1 = DummyRect.new(10, 10, 20, 20)
		r2 = DummyRect.new(30, 10, 20, 20)
		w = WhiteboardCompositeObject.new([r1, r2])

		w.move_by(5, 5)
		assert_rect_equal_wh(r1, 15, 15, 20, 20)
		assert_rect_equal_wh(r2, 35, 15, 20, 20)
	end

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
