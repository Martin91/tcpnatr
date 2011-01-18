module Gateway
  module Common
    KEEPALIVE_TIMEOUT = 20

    def handle_accept
      begin
        while (sockets = IO.select([@peer_socket, @client_socket]))
          timeout(1) do
            sockets[0].each do |socket|
              if socket == @client_socket
                @writemsg = Message.new
                @writemsg.read_from_client(@client_socket)
                @writemsg.write_to_peer(@peer_socket)
              else
                @readmsg ||= Message.new
                @readmsg.read_from_peer(@peer_socket)
                if @readmsg.read_complete?
                  unless @readmsg.payload?
                    if @readmsg.fin?
                      $stderr.puts("received fin sending finack")
                      finack = Message.new(Message::FINACK)
                      finack.write_to_peer(@peer_socket)
                      @client_socket.close unless @client_socket.closed?
                      @readmsg = nil
                      return
                    elsif @readmsg.finack?
                      $stderr.puts("received finack")
                      @client_socket.close unless @client_socket.closed?
                      @readmsg = nil
                      return
                    elsif @readmsg.keepalive?
                      $stderr.puts("received keepalive")
                      @readmsg = nil
                      return
                    end
                  end
                  $stderr.puts("reading from peer socket, writing to client")
                  @readmsg.write_to_client(@client_socket)
                  @readmsg = nil
                end
              end
            end
          end
        end
      rescue EOFError, Errno::ECONNRESET, IOError, Errno::EAGAIN, Timeout::Error => e
        $stderr.puts e.message
        finish
      end
    end

    def finish
      $stderr.puts("sending fin")
      fin = Message.new(Message::FIN)
      fin.write_to_peer(@peer_socket)

      loop do
        begin
          timeout(0.5) do
            sockets = IO.select([@peer_socket])
            @readmsg ||= Message.new
            @readmsg.read_from_peer(@peer_socket)
            if @readmsg.read_complete?
              unless @readmsg.payload?
                if @readmsg.finack?
                  $stderr.puts("received finack")
                  @client_socket.close unless @client_socket.closed?
                  @readmsg = nil
                  return
                end
              end
            end
            @readmsg = nil
          end
        rescue Timeout::Error
          $stderr.puts("timeout cleaning socket")
          @client_socket.close unless @client_socket.closed?
          return
        end
      end
    end

    def keepalive                                                                    
      keepalive = Message.new(Message::KEEPALIVE)                                                     
      keepalive.write_to_peer(@peer_socket)                                          
    end
  end
end