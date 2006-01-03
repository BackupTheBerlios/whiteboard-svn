#!/usr/bin/env ruby -w

require 'socket'

class NetworkInterface < Qt::Object
	signals 'connection(QString*, int)', 'event(QString*)'

  def initialize(port, &action)
		super(nil)
    @serverSocket = TCPServer.new("", port)
    @serverSocket.setsockopt( Socket::SOL_SOCKET, Socket::SO_REUSEADDR, 1 )
		@descriptors = [@serverSocket]
		@peers = []
		@action = action
  end # initialize

	def run()
		while true
			res = select( @descriptors, nil, nil )
			if res != nil then
				# Iterate through the tagged read descriptors
				for sock in res[0]
					# Received a connect to the server (listening) socket
					if sock == @serverSocket then
						newsock = @serverSocket.accept
						@descriptors.push( newsock )
						str = sprintf("Client joined %s:%s %s\n",
													newsock.peeraddr[2], newsock.peeraddr[1], newsock.class.to_s)
						#broadcast_string( str, newsock )
						emit connection(newsock.peeraddr[2], newsock.peeraddr[1])
					else
						# Received something on a client socket
						if sock.eof? then
							sock.close
							@descriptors.delete(sock)
							emit event('disconnection')
						else
							# we translate the newline characters as the YAML string
							# is multiple lines but when we receive we only get one line at a time
							received = sock.gets().tr('#', "\n")
							puts "received #{received}"
							m = received.match(/hello:([^:]*):(\d*)/)
							if m != nil
								puts "received hello"
								@peers << TCPSocket.open(m[1], m[2].to_s)
							else
								emit event(received)
							end
						end
					end
				end
			end
		end
	end

	def broadcast_string(str, omit_sock)
		# we translate the newline characters as the YAML string
		# is multiple lines but when we receive we only get one line at a time
		str2 = str.tr("\n", '#')
		@peers.each do |clisock|
			if clisock != @serverSocket and clisock != omit_sock 
				puts "writing #{str2} to #{clisock.peeraddr[1]}"
				
				# why do i have to this instead of the next line???
				# (if you use the existing clisock object the message is not sent until you disconnect)
				TCPSocket.open(clisock.peeraddr[2], clisock.peeraddr[1]).send(str2, 0)
				#clisock.send(str2, 0)
			end
		end
	end 

	def add_peer(location, port)
		sock = TCPSocket.open(location, port)
		@peers << sock
		#sock.send("hello:#{location}:#{port}", 0)
	end
end #server

