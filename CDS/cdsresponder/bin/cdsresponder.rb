#!/usr/bin/env ruby

require 'raven'
require 'logger'
require 'ConfigFile'
require 'FinishedNoticiation'
require 'Network'
require 'CDSResponder'
require 'trollop'

def clean_shutdown(responders,server,timeout)
  #can't use logger here because it's called from a trap context :(
  responders.each { |queue,resp|
    puts "Shutting down responders for queue #{queue}"
    resp.should_finish=true
  }
  responders.each { |queue,resp|
    puts "Waiting for termination of responder for queue #{queue}"
    if resp.join(timeout)==nil
      puts "Queue responder for #{queue} failed to terminate after #{timeout} seconds, forcibly terminating"
      resp.kill
    end
  }
  puts "All responders shut down, terminating server"
  server.shutdown
end

### START MAIN
logger = Logger.new(STDOUT)
#Process any commandline options
$options = Trollop::options do
  opt :configfile, "Path to the configuration file", :type=>:string, :default=>"/etc/cdsresponder.conf"
  opt :region, "AWS region to work in", :type=>:string, :default=>"eu-west-1"
  opt :port, "Port to bind to for healthcheck and monitoring", :type=>:integer, :default=>8000
end

#Read in the configuration file.  cfg is declared as a global variable ($ prefix)
begin
  $cfg=ConfigFile.new($options[:configfile])
rescue Exception => e
  logger.error("Unable to load configuration file: #{e.message}  Please consult the documentation, the online cdsconfig configuration tool or run with the -h option, for more information")
  raise
end

Raven.configure do |config|
  config.dsn = $cfg.var['raven-dsn'] if($cfg.var['raven-dsn'])
end

Raven.capture do
  begin
    logger.info("Commandline options:")
    logger.info($options)
    logger.info("Loaded config:")
    logger.info($cfg)

    startup_responders
    startup_networkreceiver

    #exit on ctrl-c or term
    trap 'INT' do clean_shutdown(responders,server,60) end
    trap 'TERM' do clean_shutdown(responders,server,60) end

    #run the webrick server.  This will block until the server.shutdown is called, which is done in the clean_shutdown function
    server.start

  end
end #raven.capture
