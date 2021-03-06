#!/usr/bin/ruby
require 'socket'

class Session < Struct.new(:sid,:socket,:port)
  def message
    "#{ip}:#{port}"
  end

  def port
    socket.peeraddr[1]
  end

  def ip
    socket.peeraddr[3]
  end

  def to_s
    "#{sid}: #{ip}:#{port}"
  end
end

class PortServer
  attr_reader(:port,:sessions,:server)

  def initialize(port)
    @port     = port
    @sessions = {}
    @polling  = false
  end

  def start
    server = TCPServer.new(port)
    puts "starting port server.  waiting for sessions"
	
    while (socket = server.accept)
      handle_accept(socket)
      poll_open_sessions
    end
  end

  def poll_open_sessions
    return if @polling

    Thread.new do
      @polling = true
      while !@sessions.empty?
        @sessions.each_value do |s|
          if s.socket.eof?
            puts "closing #{s.sid}"
            s.socket.close
            @sessions.delete(s.sid)
          end
        end
      end
      @polling = false
    end
  end

  def handle_accept(socket)
    port = socket.peeraddr[1]
    sid  = socket.gets.chomp
    register_session(Session.new(sid,socket,port))
  end

  def register_session(session)
    info("handling session #{session}")
    if other = sessions.delete(session.sid)
      info("found corresponding session #{other}")
      other.socket.puts(session.message)
      session.socket.puts(other.message)
      other.socket.close
      session.socket.close
    else
      info("waiting for second session #{session.sid}")
      sessions[session.sid] = session
    end
  end

  def info(msg)
    $stderr.puts(msg)
  end
end

if $0 == __FILE__
  PortServer.new(2000).start
end
