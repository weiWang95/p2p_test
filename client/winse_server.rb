class WinseServer
  attr_reader :client, :clients, :port
  attr_reader :logger

  def initialize(client, port)
    @client  = client
    @port    = port
    @clients = {}
    @logger  = ::Logger.new(STDOUT)
  end

  def run
    logger.info("p2p server run: #{port}")

    loop do
      Thread.start(server.accept) do |cli|
        uuid = cli.gets.chop
        clients[uuid] = cli

        begin
          while str = cli.gets.chop
            logger.info("[P2P Client: #{uuid}] #{str}")

            if str == WinseClient::CLOSE_CLIENT_COMMAND
              cli.puts(WinseClient::CLOSE_CLIENT_COMMAND)
              break
            end

            cli.puts 'ok'
          end
        rescue RuntimeError => ex
          logger_error(ex)
        ensure
          logger.info("[P2P Client: #{uuid}] exited!")
          clients.delete(uuid)
          cli.close
        end
      end
    rescue Interrupt => _
      logger.info('P2P Server exiting ~')
    rescue RuntimeError => ex
      logger_error(ex)
    ensure
      logger.info('P2P Server exited!')
    end
  end

  def pierce(address)
    addr = address.split(':')
    TCPSocket.open(addr.first, addr.last) rescue nil
  end

  private

  def logger_error(error)
    logger.error(error.message)
    error.backtrace.each { |message| logger.error(message) }
  end

  def server
    @server ||= TCPServer.open(port)
  end
end