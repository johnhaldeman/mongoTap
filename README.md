#mongoTap

The mongoTap is a Type 1 Guardium STAP for mongoDB. MongoDB is a NoSQL document database that stores and retrieves JSON objects. It has gained some popularity in recent years because of its speed, simplicity, and scalability. For a list of real life mongoDB use cases, see [this link](http://www.mongodb.org/about/production-deployments/). Guardium is a Database Activity Monitoring System now owned and developed by IBM. Among other things, Guardium monitors, audits, and reports on database transactions.

The mongoTap is programmed in Ruby and follows the Guardium universal feed protocol explained in [this article](http://www.ibm.com/developerworks/data/library/techarticle/dm-1210universalfeed/index.html) and [this article](http://www.ibm.com/developerworks/data/library/techarticle/dm-1211universalfeed2/index.html). The mongoTap provides a feed of mongoDB transactions to Guardium for collection and reporting. The mongoTap is still under development, but has been shown to forward all simple mongoDB transactions to a Guardium collector for logging. It has been tested for insert, remove, update, and find transactions, as well as other calls to system and database functions (for example "show collections", db.authenticate, etc). The mongoTap also keeps track of user switching in mongoDB environments where authentication is enabled.

##Architecture and Prerequisites
The mongoTap's architecture consists of two parts: A mongoDB transaction forwarder (the mongoTap client) and a traffic receiver/parser (the mongoTap server). The client forwards mongoDB transactions to the server, which then parses and translates the data into a format that a Guardium collector understands. The server forwards the reformatted traffic to a Guardium collector.

The mongoTap client uses the [mongosniff utility](http://docs.mongodb.org/manual/reference/mongosniff/) to collect the transactions occurring in mongoDB. The mongoTap server uses the Ruby [EventMachine](http://rubyeventmachine.com/) library (for connection/data handling), [protocol buffers](http://code.google.com/p/ruby-protobuf/) (to communicate with the collector), and [bindata](http://bindata.rubyforge.org/) (to build Guardium's wrapper messages).

Because of these dependencies, the following prerequisites are required to run the mongoTap:

###mongoTap Client Prerequisites:
- Ruby 1.9 and above
- mongosniff and access to mongosniff
- Because mongosniff is a unix-only utility (it relies on PCAP), the mongoTap will only work on linux and unix platforms

###mongoTap Server Prerequisites:
- Ruby 1.9 and above
- The EventMachine gem installed
- The protobuf gem installed
- The bindata gem installed

The mongoTap was tested with Guardium V9, but it seems to work in Guardium V8.2 as well. Other versions of Guardium have not been tried.

##Installing and Starting mongoTap

Put the mongoTap client software (MongoTapClient.rb) on the mongoDB server and execute:
```
ruby MongoTapClient.rb <mongoTap_server_ip> <mongo_bin_path> <network_int>
	where: 
		<mongoTap_server_ip> is the IP address of the mongTap server
		<mongo_bin_path> is the path to the bin folder for mongoDB
		<network_int> is the network interface name
	example: ruby MongoTapClient.rb 10.10.9.150 /opt/mongodb-linux-x86_64-2.2.1/bin eth0
```
Put all of the mongoTap software on a server and execute:
```
usage: ruby MongoTapServer.rb <listen_ip> <collector_ip>\n
	where:
		<listen_ip> is the IP address of the network interface you want to listen on
		<collector_ip> is the IP address of the Guardium Collector to report to
	example: ruby MongoTapServer.rb 10.10.9.28 10.10.9.248
```


##Future Development
The following are some obvious areas for improvement:
- Further testing is likely to be required to support all mongoDB transaction types
- Communication between the mongoTap client and server is fairly primitive in that the monoTap client will not reconnect if a connection is lost and will not buffer traffic if the mongoTap server fails. 
- The TapUtils library requires a little bit of work to make it a generic library for building Ruby based STAPs
- There is no need, and little advantage, in having the mongoTap coded Ruby. It could be replaced with something else to remove that dependency on the mongoDB server
- No testing has been done to ensure that the mongoTap works in sharded or other distributed environments. Theoretically, if mongosniff works, so should the mongoTap
- Returned data and exception handling could be implemented so that additional fields and areas of Guardium are populated

##License
The mongTap is released under the MIT license. The components that mongoTap uses (eg: EventMachine, IBM InfoSphere Guardium) have their own licenses.

##About the Author
The mongoTap was developed by John Haldeman as a side project. John currently works as the Security Practice Lead at Information Insights LLC. If you would like to contribute to the mongoTap, or have any questions about it, you can contact him at john.haldeman@infoinsightsllc.com


