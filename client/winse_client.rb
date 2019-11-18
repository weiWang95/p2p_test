require 'logger'
require 'socket'

require_relative './winse_server'

class WinseClient
  SPLIT_FLAG = '-||-'.freeze
  CLOSE_CLIENT_COMMAND = 'bye'.freeze
  P2P_HOST_COMMAND = 'p2p_server'.freeze
  P2P_PIERCE_COMMAND = 'p2p_pierce'.freeze
  P2P_CLIENT_COMMAND = 'p2p_client'.freeze
  P2P_ERROR_COMMAND = 'p2p_error'.freeze

  attr_reader :host, :port, :uuid
  attr_reader :logger
  attr_reader :server, :p2p, :p2p_client

  def initialize(host, port)
    @host = host
    @port = port
    @p2p  = false

    @logger = ::Logger.new(STDOUT)
  end

  def run
    client.puts("Name#{Random.rand(100).to_i}")
    @uuid = client.gets.chop
    Thread.start do
      while str = gets.chop
        if p2p && p2p_client

          p2p_client.puts str
          if str == CLOSE_CLIENT_COMMAND
            @p2p = false
          end
          next
        end

        logger.info(str)

        if str.start_with?(P2P_HOST_COMMAND)
          host_port = str.split(SPLIT_FLAG).last
          @server = WinseServer.new(self, host_port)
          Thread.start(@server){ |server| server.run }

          client.puts([P2P_HOST_COMMAND, host_port].join(SPLIT_FLAG))
          next
        end

        client.puts str
        break if str == CLOSE_CLIENT_COMMAND
      end
    end

    while str = client.gets.chop
      break if str == CLOSE_CLIENT_COMMAND

      if str.start_with?(P2P_CLIENT_COMMAND)
        server_address = str.split(SPLIT_FLAG).last
        addr = server_address.split(':')
        @p2p = true
        @p2p_client = TCPSocket.open(addr.first, addr.last)
        logger.info('p2p client listen')
        Thread.start(@p2p_client) do |cli|
          cli.puts(uuid)
          while s = cli.gets.chop
            break if s == CLOSE_CLIENT_COMMAND

            logger.info("[P2P Server]: #{s}")
          end
        rescue Interrupt => _
          logger.info('P2P Client exiting ~')
        rescue RuntimeError => ex
          logger_error(ex)
        ensure
          cli.close
          @p2p = false
          @p2p_client = nil
          logger.info('P2P Client Exited')
        end

        next
      end

      if str.start_with?(P2P_PIERCE_COMMAND)
        arr = str.split(SPLIT_FLAG)
        uuid = arr[1]

        server && server.pierce(arr.last)
        client.puts([P2P_PIERCE_COMMAND, uuid].join(SPLIT_FLAG))

        next
      end

      if str.start_with?(P2P_ERROR_COMMAND)
        p2p_client && p2p_client.close rescue nil
        @p2p = false
        @p2p_client = nil
        next
      end

      logger.info("\033[31m #{str} \033[0m")
      # client.puts CLOSE_CLIENT_COMMAND
    end
  rescue Interrupt => _
    logger.info('Client exiting ~')
  rescue RuntimeError => ex
    logger_error(ex)
  ensure
    client.close
    logger.info('Client exited!')
  end

  def client
    @client ||= TCPSocket.open(host, port)
  end

  private

  def logger_error(error)
    logger.error(error.message)
    error.backtrace.each { |message| logger.error(message) }
  end
end

WinseClient.new('192.168.2.63', 40000).run
