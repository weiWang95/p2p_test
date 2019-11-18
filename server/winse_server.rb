require 'logger'
require 'socket'

require_relative './client'

class WinseServer
  attr_reader :port, :logger
  attr_reader :clients


  def initialize(port = 40000)
    @port   = port
    @logger = ::Logger.new(STDOUT)
    @clients = {}
  end

  def run
    logger.info('Server start ~')

    loop do
      Thread.start(server.accept) do |cli|
        client = Client.new(cli)
        clients[client.uuid] = client
        logger.info("Accept Client: #{client.address}")
        client.client.puts(client.uuid)

        begin
          while str = client.client.gets.chop
            logger.info("[Client: #{client.uuid}] #{str}")
            break if str == Client::CLOSE_CLIENT_COMMAND # exit

            if str.start_with?(Client::P2P_HOST_COMMAND) # p2p host
              host_port = str.split(Client::SPLIT_FLAG).last
              client.host = true
              client.host_port = host_port
              next
            end

            if str.start_with?(Client::P2P_CLIENT_COMMAND) # p2p client
              host_uuid = str.split(Client::SPLIT_FLAG).last
              host = clients[host_uuid]
              if host && host.host?
                host.client.puts([Client::P2P_PIERCE_COMMAND, client.uuid, client.address].join(Client::SPLIT_FLAG))
              else
                client.client.puts(Client::P2P_ERROR_COMMAND)
              end

              next
            end

            if str.start_with?(Client::P2P_PIERCE_COMMAND) # p2p pierce
              uuid = str.split(Client::SPLIT_FLAG).last
              clients[uuid].client.puts([Client::P2P_CLIENT_COMMAND, client.host_address].join(Client::SPLIT_FLAG))
              next
            end

            clients.values.each do |c|
              next if c.uuid == client.uuid
              c.client.puts "[Client: #{client.uuid}] #{client.name}: #{str}"
            end
          end
        rescue RuntimeError => ex
          logger_error(ex)
        ensure
          logger.info("[Client: #{client.uuid}] exited!")
          clients.delete(client.uuid)
          client.close
        end
      end
    end
  rescue Interrupt => _
    logger.info('Server exiting ~')
  rescue RuntimeError => ex
    logger_error(ex)
  ensure
    logger.info('Server exited!')
  end

  def server
    @server ||= TCPServer.open(port)
  end

  private

  def logger_error(error)
    logger.error(error.message)
    error.backtrace.each { |message| logger.error(message) }
  end
end

WinseServer.new.run