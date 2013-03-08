#!/usr/bin/env ruby

require 'socket'

puts "\n\nMongoTap - Open Source Type 1 Guardium STAP for mongoDB\n\n"

unless(ARGV.length >= 3)
    puts "usage: ruby MongoTapClient.rb <mongoTap_server_ip> <mongo_bin_path> <network_int>\n"
    puts " where: "
    puts "  <mongoTap_server_ip> is the IP address of the mongTap server"
    puts "  <mongo_bin_path> is the path to the bin folder for mongoDB"
    puts "  <network_int> is the network interface name"
    puts "example: ruby MongoTapClient.rb 10.10.9.150 /opt/mongodb-linux-x86_64-2.2.1/bin eth0"
    exit
end

hostname = ARGV[0]
bin_path = ARGV[1]
interface = ARGV[2]
port = 16028

puts 'Monitoring ' + interface + "..."

session = TCPSocket.open(hostname, port)

IO.popen (bin_path + "/mongosniff --source NET " + interface) do |f|
   while s = f.gets
        session.puts s
   end
end

