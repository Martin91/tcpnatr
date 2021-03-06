require 'client_request'
require 'timeout'
require 'peer_server'
require 'message'
require 'gateway_common'
require 'gateway_server'
require 'thread'

module Gateway
  class Client
    include Gateway::Common
    attr_reader(:port, :host, :peer_socket, :client)

    def initialize(host, port)
      @host     = host
      @port     = port
      @mutex    = Mutex.new
      @requests = {}
    end

    def start_stunt
      port_client   = PortClient.new("blastmefy.net:2000")
      @peer_socket  = PeerServer.new(port_client).start("testy", 2004)
    end

    def start
      $stderr.puts("starting nat traversal")
      start_stunt
      handle_peer
    end
  end
end

if $0 == __FILE__
  Gateway::Client.new('localhost', 3001).start
end
