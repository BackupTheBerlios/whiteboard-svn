#!/usr/bin/env ruby -w

require 'network'
require 'test/unit'
require 'Qt'

class NetworkTestObject < Qt::Object
	attr_reader :server, :client, :server_messages, :client_messages
	slots 'server_message(QString*)', 'client_message(QString*)'

	def initialize()
		super(nil)

		@server_messages = []
		@client_messages = []
	
		@server = NetworkInterface.new()
		connect(@server, SIGNAL('message(QString*)'), SLOT('server_message(QString*)'))
		@server.start_server(2627)
		
		@client = NetworkInterface.new()
		connect(@client, SIGNAL('message(QString*)'), SLOT('client_message(QString*)'))
		@client.start_client('localhost', 2627)
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
	end
end
