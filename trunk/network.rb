#!/usr/bin/env ruby -w

require 'socket'
require 'Qt'

class NetworkInterface < Qt::Object
	signals 'message(QString*)'
	slots 'message(QString*)'

	def initialize()
		super(nil)
		@object = nil
	end
	
	def message(m)
		emit message(m)
	end

	def start_server(port)
		@object = NetworkServer.new( port)
		connect(@object, SIGNAL('message(QString*)'), SLOT('message(QString*)'))
		@object.run()
	end

	def start_client(host, port)
		@object = NetworkClient.new(host, port)
		connect(@object, SIGNAL('message(QString*)'), SLOT('message(QString*)'))
		@object.run()
	end
	
	def run()
		@object.run()
	end

	def started?() @object != nil end

	def broadcast_message(msg)
		@object.write(msg.to_line) if @object != nil
	end

	def broadcast_string(str)
		@object.write(str) if @object != nil
	end

	def stop() @object.stop() end
end 

class NetworkServer < Qt::Object
	signals 'message(QString*)'

	def initialize(port)
		super(nil)
		@port = port
		@socket = TCPServer.new('', port)
		@socket.setsockopt( Socket::SOL_SOCKET, Socket::SO_REUSEADDR, 1 )
		@sessions = []
		@is_running = false
	end

	def run()
		return if @is_running 
		@is_running = true
		@thr = Thread.start do
			while @is_running
				s = select([@socket] + @sessions, nil, nil)
				if s != nil
					s[0].each do |sock|
						if sock == @socket
							new_sock = sock.accept()
							@sessions << new_sock 
						elsif sock.eof()
							@sessions.delete(sock)
						else
							line = sock.gets()
							emit message(line)
							@sessions.each { |s| s.print line if s != sock }
						end
					end
				end
			end
		end
	end

	def stop() 
		@is_running = false
		@thr.kill() 
		@socket.shutdown()
	end

	def write(s)
		@sessions.each { |ses| ses.print s }
	end
end

class NetworkClient < Qt::Object
	signals 'message(QString*)'

	def initialize(host, port)
		super(nil)
		@socket = TCPSocket.new(host, port)
		@is_running = false
	end

	def run()
		return if @is_running 
		@is_running = true
		@thr = Thread.new do
			while @is_running
				str = @socket.gets()
				emit message(str) if str != nil
			end
		end
	end
	
	def stop() 
		@is_running = false
		@thr.kill() 
		@socket.shutdown()
	end

	def write(s)
		@socket.write(s)
	end
end

class NetworkMessage
	def to_line()
		YAML.dump(self).tr("\n", '#') + "\n"
	end

	def NetworkMessage.from_line(s)
		YAML.load(s.tr('#', "\n").chomp())
	end
end

class CreateObjectMessage < NetworkMessage
	attr_reader :object

	def initialize(object)
		@object = object
	end
	
	def to_yaml_properties() %w{ @object } end
end

class MoveObjectMessage < NetworkMessage
	attr_reader :object_id, :x, :y

	def initialize(object_id, x, y)
		@object_id, @x, @y = object_id, x, y
	end

	def to_yaml_properties() %w{ @object_id @x @y } end
end

class ResizeObjectMessage < NetworkMessage
	attr_reader :object_id, :mx, :my, :dx, :dy

	def initialize(object_id, mx, my, dx, dy)
		@object_id, @mx, @my, @dx, @dy = object_id, mx, my, dx, dy
	end

	def to_yaml_properties() %w{ @object_id @mx @my @dx @dy } end
end

class DeleteObjectMessage < NetworkMessage
	attr_reader :object_id

	def initialize(object_id)
		@object_id = object_id
	end

	def to_yaml_properties() %w{ @object_id } end
end

class ChangeObjectMessage < NetworkMessage
	attr_reader :object

	def initialize(object)
		@object = object
	end

	def to_yaml_properties() %w{ @object } end
end
