#!/usr/bin/env ruby

require 'socket' 
require 'eventmachine'
require 'logger'
require_relative 'TapUtils'

LOGFILE = "mongoTap.log"
LOGLEVEL = Logger::DEBUG

module MTLogger
  MTLogger = Logger.new(LOGFILE)
  MTLogger.level = LOGLEVEL
end

class MongoTapGuardClient < EventMachine::Connection
  include MTLogger
  attr_accessor :tap_ip
  
  def post_init
    MTLogger.info("Starting mongoTap Guardium STAP Client")
    MTLogger.info('Sending handshake');
    tap_name = 'mongoTapCollector'
    tap_version = 'mongoTap_v0.1'
    
    EventMachine.add_timer(5) {
      handshake = GuardiumHandshakeMessage.new(@tap_ip, tap_name, @tap_ip, tap_version)
      send_data(handshake.getWrappedGuardiumMessage)
    }
    
    EventMachine.add_periodic_timer(30) {
        MTLogger.debug('sending ping')
        ping = GuardiumPingMessage.new(@tap_ip, tap_name, @tap_ip)
        send_data(ping.getWrappedGuardiumMessage)
      }

  end
  
  def receive_data(data)
  end
end


class MongoSession
  attr_accessor :clientIP, :clientPort, :serverIP, :serverPort, :currentMongoUser,
                :currentDB, :currentCollection, :currentID
  
  def initialize(clientIP, clientPort, serverIP, serverPort)
    @clientIP = clientIP
    @clientPort = clientPort
    @serverIP = serverIP
    @serverPort = serverPort
    @currentMongoUser = "NO_AUTH"
  end
  
end

class MongoTapServer < EventMachine::Connection
  include MTLogger
  
  attr_accessor :guardClient, :currentLine, :sessionList, :currentSession
  
  def initialize
    super()
    @currentLine = ""
    @sessionList = Hash.new
    MTLogger.info("Starting mongoTap Server")
  end

  def receive_data(data)
    
     if data.to_s =~ /\n/ then
       processNewLine(data)
     else
       @currentLine = @currentLine + data
     end
     
  end
  
  def processNewLine(data)    
    splitLines = data.split("\n")
    
    splitLines.each do |line|
      if(line != nil)
        parseLine(@currentLine)
        @currentLine = line
      else
        @currentLine = ""
      end      
    end
    
    if(@currentLine.length > 0)
      parseLine(@currentLine)
      @currentLine = ""
    end

  end
  
  def parseLine(line)
    if line.start_with?("\t") then
      parseContinuationLine(line)
    else
      parseNewMessageLine(line)
    end
  end
  
  def parseNewMessageLine(line)
    
    MTLogger.debug("parsing new message line " + line)
    
    regex = /^(?<client_ip>\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}):(?<client_port>\d{1,5})\s+--\>\>\s+(?<server_ip>\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}):(?<server_port>\d{1,5})\s+(?<db>\S+)\.(?<collection>\S+)\s+(?<length>\d+)\s+bytes\s+id:(?<hex_id>[0-9a-f]+)\s+(?<dec_id>\d+)\s*$/
    
    matches = regex.match(line)
    
    if matches then
    #found a client request
    
      transServerIP = matches["server_ip"]
      
      if transServerIP == '127.0.0.1'
        #if the client is connecting to localhost, subsititute with the IP of the mongoTap client        
        transPort, transServerIP = Socket.unpack_sockaddr_in(get_peername)
      end
      
      key = matches["client_ip"] + ":" + matches["client_port"] + "-" + transServerIP + ":" + matches["server_port"]
      
      if @sessionList.has_key?(key)
        @currentSession = @sessionList[key]
      else
        @currentSession = MongoSession.new(matches["client_ip"],  matches["client_port"],
            transServerIP, matches["server_port"])
        
        @sessionList[key] = @currentSession
        
        MTLogger.debug('Sending Session Start Message')
        sessionStart = GuardiumNewSessionMessage.new(100, matches["client_ip"], matches["client_port"].to_i, transServerIP, matches["server_port"].to_i)
        @guardClient.send_data(sessionStart.getWrappedGuardiumMessage)
      end
      @currentSession.currentDB = matches["db"]
      @currentSession.currentCollection = matches["collection"]
      @currentSession.currentID = matches["dec_id"]
      
    elsif line.include?("<<--")
    #found a server response, ignorning for now
      #TODO Process Return messages
            
    else
    #found something we didn't expect 
      MTLogger.debug("Unexpected mongosniff line: " + line)
      
    end
    
  end
  
  def parseContinuationLine(line)
    MTLogger.debug("parsing continuation line " + line)
    
    regex = /^\s+(?<operation>\S+)\s*(?<del_flags> flags:.+q)?:\s*(?<json_object>{.*})(?<remainder>.*)$/
    
    matches = regex.match(line)
    
    if matches then
    #found a valid continuation message
      MTLogger.debug('Sending Client Request Message')
      object = @currentSession.currentDB + "." + @currentSession.currentCollection
            
      if matches["json_object"].include?("authenticate")
        user_regex = /user: \"(?<user>.*?)\"/
        user_matches = user_regex.match(matches["json_object"])
        @currentSession.currentMongoUser = user_matches["user"]
        
      end
        
      
      clientRequest = GuardiumSingleSentenceClientRequestMessage.new(@currentSession.currentID.to_i, 
                  100, 
                  @currentSession.clientIP,
                  @currentSession.clientPort.to_i, 
                  @currentSession.serverIP, 
                  @currentSession.serverPort.to_i, 
                  matches["operation"], object, 
                  object + "." + matches["operation"] + matches["json_object"], 
                  @currentSession.currentMongoUser)
      @guardClient.send_data(clientRequest.getWrappedGuardiumMessage)
    else
      MTLogger.debug("Unexpected mongosniff line (countinuation): " + line)
    end
    
  end

end



puts "\n\nMongoTap - Open Source Type 1 Guardium STAP for mongoDB\n\n"

unless(ARGV.length >= 2)
    puts "usage: ruby MongoTapServer.rb <listen_ip> <collector_ip>\n"
    puts " where: "
    puts "  <listen_ip> is the IP address of the network interface you want to listen on"
    puts "  <collector_ip> is the IP address of the Guardium Collector to report to\n\n"
    puts "example: ruby MongoTapServer.rb 10.10.9.28 10.10.9.248"
    exit
end

listen_ip = ARGV[0]
collector_ip = ARGV[1]


EventMachine::run do
  EventMachine.connect(collector_ip, 16016, MongoTapGuardClient) do |clientconn|
    clientconn.tap_ip = listen_ip
    EventMachine.start_server(listen_ip, 16028, MongoTapServer) do |serverconn|
      serverconn.guardClient = clientconn
    end
    puts 'Listening...'
  end
end
