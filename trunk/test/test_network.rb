#!/usr/bin/env ruby -w

require 'network'
require 'test/unit'
require 'main_helper'
require 'Qt'

$a = Qt::Application.new([]) if not defined?($a)

class NetworkTestObject < Qt::Object
	attr_reader :server, :client, :server_messages, :client_messages

	def initialize()
		super(nil)

		@server_messages = []
		@client_messages = []
	
		@server = NetworkInterface.new()
		@server.start_server(2627) { |s| @server_messages << s }
		
		@client = NetworkInterface.new()
		@client.start_client('localhost', 2627) { |s| @client_messages << s }
	end

	def server_message(s)
		@server_messages << s
	end

	def client_message(s)
		@client_messages << s
	end
end

class TestNetwork < Test::Unit::TestCase
	def test_network()
		n = NetworkTestObject.new()
		n.client.broadcast_string("hello\n")
		n.client.broadcast_message(CreateObjectMessage.new("my object"))
		n.client.broadcast_message(MoveObjectMessage.new("move object id", 25, 36))
		n.client.broadcast_message(ResizeObjectMessage.new("resize object id", 1, 2, 3, 4))
		n.client.broadcast_message(DeleteObjectMessage.new("delete object id"))
		sleep(2)
		assert_equal(5, n.server_messages.length)
		assert_equal("hello\n", n.server_messages[0])

		m = NetworkMessage.from_line(n.server_messages[1])
		assert_equal(true, m.is_a?(CreateObjectMessage))
		assert_equal("my object", m.object)
		
		m = NetworkMessage.from_line(n.server_messages[2])
		assert_equal(true, m.is_a?(MoveObjectMessage))
		assert_equal("move object id", m.object_id)
		assert_equal(25, m.x)
		assert_equal(36, m.y)

		m = NetworkMessage.from_line(n.server_messages[3])
		assert_equal(true, m.is_a?(ResizeObjectMessage))
		assert_equal("resize object id", m.object_id)
		assert_equal(1, m.mx)
		assert_equal(2, m.my)
		assert_equal(3, m.dx)
		assert_equal(4, m.dy)

		m = NetworkMessage.from_line(n.server_messages[4])
		assert_equal(true, m.is_a?(DeleteObjectMessage))
		assert_equal("delete object id", m.object_id)
		
		n.server.broadcast_string("hello\n")
		n.server.broadcast_message(CreateObjectMessage.new("my object"))
		n.server.broadcast_message(MoveObjectMessage.new("move object id", 25, 36))
		n.server.broadcast_message(ResizeObjectMessage.new("resize object id", 1, 2, 3, 4))
		n.server.broadcast_message(DeleteObjectMessage.new("delete object id"))
		sleep(2)
		assert_equal(5, n.client_messages.length)
		assert_equal("hello\n", n.client_messages[0])

		m = NetworkMessage.from_line(n.client_messages[1])
		assert_equal(true, m.is_a?(CreateObjectMessage))
		assert_equal("my object", m.object)
		
		m = NetworkMessage.from_line(n.client_messages[2])
		assert_equal(true, m.is_a?(MoveObjectMessage))
		assert_equal("move object id", m.object_id)
		assert_equal(25, m.x)
		assert_equal(36, m.y)

		m = NetworkMessage.from_line(n.client_messages[3])
		assert_equal(true, m.is_a?(ResizeObjectMessage))
		assert_equal("resize object id", m.object_id)
		assert_equal(1, m.mx)
		assert_equal(2, m.my)
		assert_equal(3, m.dx)
		assert_equal(4, m.dy)

		m = NetworkMessage.from_line(n.client_messages[4])
		assert_equal(true, m.is_a?(DeleteObjectMessage))
		assert_equal("delete object id", m.object_id)

		n.client.stop()
		n.server.stop()
	end

	def test_app_networking()
		w, w2 = start_double()

		w.main_widget.prepare_object_creation(WhiteboardRectangle.new(w.main_widget))
		w.main_widget.left_mouse_press(10, 10)
		w.main_widget.left_mouse_move(30, 30)
		w.main_widget.left_mouse_release(30, 30)

		sleep(1)

		assert_equal(1, w2.main_widget.state.objects.length)

		w.stop()
		w2.stop()
	end
end
