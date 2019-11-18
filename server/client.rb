require 'securerandom'

class Client
  SPLIT_FLAG = '-||-'.freeze

  CLOSE_CLIENT_COMMAND = 'bye'.freeze
  P2P_HOST_COMMAND = 'p2p_server'.freeze
  P2P_PIERCE_COMMAND = 'p2p_pierce'.freeze
  P2P_CLIENT_COMMAND = 'p2p_client'.freeze
  P2P_ERROR_COMMAND = 'p2p_error'.freeze

  attr_reader :client, :uuid, :name
  attr_accessor :host, :host_port

  def initialize(client)
    @client = client
    @uuid   = ::SecureRandom.hex(4)
    @name   = client.gets.chop
    @host   = false
  end

  def ip
    @_ip ||= client.peeraddr&.fetch(2)&.split(':')&.last
  end

  def port
    @_port ||= client.peeraddr&.fetch(1)
  end

  def address
    "#{ip}:#{port}"
  end

  def host?
    @host
  end

  def host_address
    "#{ip}:#{host_port}"
  end

  def close
    client.puts(CLOSE_CLIENT_COMMAND)
    client.close
  end

  def inspect
    "#{client.peeraddr&.fetch(2)}:#{client.peeraddr&.fetch(1)}"
  end
end