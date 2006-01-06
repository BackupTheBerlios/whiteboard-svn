#!/usr/bin/env ruby -w

require 'socket'

class NetworkInterface < Qt::Object
	signals 'event(QString*)'
	slots 'event(QString*)'

	def event(s)
		emit event(s)
	end

	def initialize()
		super(nil)
		@object = nil
	end

	def start_server(port)
		@object = NetworkServer.new( port)
		connect(@object, SIGNAL('event(QString*)'), SLOT('event(QString*)'))
	end

	def start_client(host, port)
		@object = NetworkClient.new(host, port)
		connect(@object, SIGNAL('event(QString*)'), SLOT('event(QString*)'))
	end
	
	def run()
		@object.run()
	end

	def started?() @object != nil end

	def broadcast_string(str)
		puts "broadcasting message #{str}"
		@object.write(str.tr("\n", '#') + "\n") if @object != nil
	end 
end 

class NetworkServer < Qt::Object
	signals 'event(QString*)'

	def initialize(port)
		super(nil)
		@port = port
		@server = TCPServer.new('', port)
		@server.setsockopt( Socket::SOL_SOCKET, Socket::SO_REUSEADDR, 1 )
		@sessions = []
	end

	def run()
		@thr = Thread.start do
			while true
				s = select([@server] + @sessions, nil, nil)
				if s != nil
					s[0].each do |sock|
						if sock == @server
							new_sock = sock.accept()
							puts "connection from #{new_sock.peeraddr[2]}"
							@sessions << new_sock #sock.accept()
							@sessions.each { |s| s.print "#{@sessions.length} sessions" }
						elsif sock.eof()
							@sessions.delete(sock)
							@sessions.each { |s| s.print "#{@sessions.length} sessions" }
						else
							str = sock.gets().tr('#', "\n")
							puts "received message #{str}"
							emit event(str)
							@sessions.each { |s| s.print str if s != sock }
						end
					end
				end
			end
		end
	end

	def join() @thr.join() end

	def write(s)
		@sessions.each { |ses| 
			puts "sending message from server"
			ses.print s 
			
		}
	end
end

class NetworkClient < Qt::Object
	signals 'event(QString*)'

	def initialize(host, port)
		super(nil)
		@sock = TCPSocket.new(host, port)
	end

	def run()
		Thread.new do
			while true
				str = @sock.gets().tr('#', "\n") #recv(100)
				puts "received at client: #{str}" if str != nil
				emit event(str) if str != nil
			end
		end
	end

	def write(s)
		@sock.write(s)
	end
end

