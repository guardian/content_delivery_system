#!/usr/bin/env ruby

require 'aws-sdk-v1'
require 'json'
require 'trollop'
require 'json'
require 'raven'
require 'webrick'
require 'logger'
require 'awesome_print'
require 'json'
require 'raven'

#Simple webrick servlet to respond to an ELB healthcheck
class HealthCheckServlet <  WEBrick::HTTPServlet::AbstractServlet
  #Returns a 200 response and 'OK' in the body in response to a GET request
  def do_GET(request,response)
    response.status = 200
    response['Content-Type'] = 'text/plain'
    response.body = 'OK'
  end
end

#Reads in the configuration file and allows simple access to the contents.
#Once you have initialised, with $cfg=ConfigFile.new(filename), you can access values with $cfg.var['key']
#or with $cfg.key
#The configuration file is simple key=value pairs; the system responds to the following keys:
#           configuration-table={dynamodb table to use for configuration}
#           routes-table={dynamodb table to use for the routes content}
#           region={AWS region to use for SQS and DynamoDB]
#           access-key={AWS access key} [Optional; default behaviour is to attempt connection via AWS roles]
#           secret-key={AWS secret key} [Optional; as above]
#           raven-dsn={Sentry DSN} [optional]
class ConfigFile
  attr_accessor :var

  def initialize(filename)
    unless File.exists?(filename)
      raise "Requested configuration file #{filename} does not exist."
    end
    @var={}
    File.open(filename, "r") { |f|
      f.each_line { |line|
        next if(line.match(/^#/))
        row=line.match(/^(?<name>[^=]+)=(?<value>.*)$/)
        @var[row['name']]=row['value'] if(row)
      }
    }
  end

  #Allows access to the key/value pairs by calling a pretend method
  #i.e., cfg.key, in order to return the value
  def method_missing(name,args,&block)
    raise KeyError if(not @var.key?(name))
    @var[name]
  end #method_missing
end

class FinishedNotification
  attr_accessor :exitcode
  attr_accessor :log
  attr_accessor :routename

  def initialize(routename, exitcode, log)
    @routename=routename
    @exitcode=exitcode
    @log=log
  end

  def to_json
    hash={}
    self.instance_variables.each do |var|
      hash[var]=self.instance_variable_get var
    end
    hash.to_json
  end

end

#This class represents the queue responder itself
#When you initialise an instance of this class, you tell it which queue to listen to and which route to execute, etc.,
#and it will initialise a background thread to keep listening.
#In order to terminate, set should_finish to true.  This will mean that the listener will terminate either after the next
#message has processed, or if no messages are processing, the idle timeout of the queue (default: 10 seconds).
#To wait for the termination of the listener, call the #join method.  To forcibly kill the thread without waiting for
#termination, call the #kill method.

class CDSResponder
  attr_accessor :url
  attr_accessor :isexecuting
  attr_accessor :should_finish

  def initialize(arn, routename, arg, notification, idle_timeout: 10)
    @routename=routename
    @cdsarg=arg
    @notification_arn=notification
    matchdata=arn.match(/^arn:aws:sqs:([^:]*):([^:]*):([^:]*)/)
    @region=matchdata[1]
    @acct=matchdata[2]
    @name=matchdata[3]
    @url="https://sqs.#{@region}.amazonaws.com/#{@acct}/#{@name}"
    @sqs=AWS::SQS::new(:region => 'eu-west-1')
    @q=@sqs.queues[@url]
    @idle_timeout = idle_timeout
    @isexecuting=1
    @should_finish=false
    @logger = Logger.new(STDOUT)

    if notification!=nil
      @sns=AWS::SNS.new(:region => 'eu-west-1')
      @notification_topic=@sns.topics[notification]
    end

    @threadref=Thread.new {
      ThreadFunc();
    }
  end

  def GetUniqueFilename(path)
    filebase=@routename.gsub(/[^\w\d]/, "_")
    filename=path+'/'+filebase+".xml"
    n=0
    while Pathname(filename).exist? do
      n=n+1
      filename=path+'/'+filebase+"-"+n.to_s+".xml"
    end
    filename
  end

  def GetRouteContent
    ddb=AWS::DynamoDB.new(:region => $options[:region])
    table=ddb.tables[$cfg.var['routes-table']]
    table.hash_key=[:routename, :string]
    item=table.items[@routename]
    item.attributes['content']
  end

#Download the route name given from the DynamoDB table and return the local filename
  def DownloadRoute
    filename=GetUniqueFilename('/etc/cds_backend/routes')

    @logger.debug("Got filename #{filename} for route file")

    File.open(filename, 'w') { |f|
      f.write(GetRouteContent())
    }
    filename
  end

#Output the message as a trigger file
  def OutputTriggerFile(contents, id)
    File.open(id+".xml", 'w') { |f|
      f.write(contents)
    }
    id+".xml"
  end

  def GetLogfile(name)
    #filename = @logpath+"/"+name+".log"
    contents = ""
    File.open(@logpath+"/"+name+".log", 'r') { |f|
      contents=f.read()
    }
    contents
  rescue
    @logger.error("Unable to read log from filename")
  end

  def ThreadFunc
    while @isexecuting do
      @q.poll(:idle_timeout=>@idle_timeout) { |msg|
        begin #start a block to catch exceptions
          @routefile=DownloadRoute()

          trigger_content=msg.body
          begin
            jsonobject = JSON.parse(msg.body) #if we're subscribed to an SNS topic we get a JSON object
            if jsonobject['Type'] == 'Notification'
              trigger_content = jsonobject['Message']
            end
          rescue JSON::JSONError
            @logger.debug("Message on queue is not JSON")
            trigger_content=msg.body
          end
          @logger.debug("trigger content:")
          @logger.debug(trigger_content)

          triggerfile=OutputTriggerFile(trigger_content, msg.id)

          @pid = spawn("cds_run", "--route", @routefile, "--#{@cdsarg}", triggerfile)
          msg=FinishedNotification.new(@routename, $?.exitstatus, GetLogfile(msg.id))
          @notification_topic.publish(msg.to_json)

        rescue Exception => e
          Raven.capture_exception(e)
          @logger.error(e.message)
          @logger.error(e.backtrace.inspect)
          begin
            @notification_topic.publish({'status' => 'error', 'message' => e.message, 'trace' => e.backtrace}.to_json)
          rescue Exception => not_excep
            Raven.capture_exception(not_excep)
            @logger.error("Error passing on error message: #{not_excep.message}")
          end

        ensure
          File.delete(triggerfile)
          File.delete(@routefile)
          #if should_finish is set while messages still on the queue, terminate immediately by breaking out of the poll
          #loop while not waiting for timeout
          if @should_finish
            @logger.info("got should_finish signal")
            @isexecuting = false
            break
          end
        end #end block to catch exceptions
      }
      #if should_finish is set while messages are NOT on the queue, then the poll times out without executing the loop break above.
      #so we must re-do the check here.
      if @should_finish
        @logger.info("got should_finish signal")
        @isexecuting = false
        break
      end
    end #while @isexecuting
    @logger.debug("reached end of threadfunc")
  end #def threadfunc

  #wait for the listener to terminate
  # +limit+:: number of seconds to wait
  # returns the thread id or nill if it timed out
  def join(limit)
    result = @threadref.join(limit)
    File.delete(@routefile) if(@routefile)
    result
  end #def join

  #forcibly terminate the listener
  def kill
    @threadref.kill
  end

end #class CDSResponder

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
  opt :port, "Port to bind to for healthcheck and montiroing", :type=>:integer, :default=>80
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

    ddb=AWS::DynamoDB.new(:region => $options[:region])

    table=ddb.tables[$cfg.var['configuration-table']]
    if !table or table==''
      raise "Unable to connect to the table #{$cfg.var['configuration-table']}.  Has this been set up yet by the system administrator?"
    end

    table.hash_key = ['queue-arn', :string]

    responders = Hash.new

    table.items.each do |item|
      begin
        for i in 1..item.attributes['threads']
          responder=CDSResponder.new(item.attributes['queue-arn'], item.attributes['route-name'], "--input-"+item.attributes['input-type'], item.attributes['notification'], idle_timeout: 10)
          responders[item.attributes['queue-arn']] = responder
          logger.info("Started up responder instance #{i} for #{item.attributes['queue-arn']}")
        end

      rescue Exception=>ex
        logger.error("Responder failed to start up for #{item.attributes['queue-arn']}\n")
        Raven.capture_exception(ex, :extra => {'message'=>"Responder failed to start up for #{item.attributes['queue-arn']}"})
        next
      end
    end

    server = WEBrick::HTTPServer.new(:Port=>$options.port)
    server.mount('/healthcheck',HealthCheckServlet)
    #exit on ctrl-c or term
    trap 'INT' do clean_shutdown(responders,server,60) end
    trap 'TERM' do clean_shutdown(responders,server,60) end

    #run the webrick server.  This will block until the server.shutdown is called, which is done in the clean_shutdown function
    server.start

  end
end #raven.capture
