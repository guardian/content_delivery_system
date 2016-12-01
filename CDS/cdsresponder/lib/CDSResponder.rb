require 'aws-sdk-v1'

#This class represents the queue responder itself
#When you initialise an instance of this class, you tell it which queue to listen to and which route to execute, etc.,
#and it will initialise a background thread to keep listening.
#In order to terminate, set should_finish to true.  This will mean that the listener will terminate either after the next
#message has processed, or if no messages are processing, the idle timeout of the queue (default: 10 seconds).
#To wait for the termination of the listener, call the #join method.  To forcibly kill the thread without waiting for
#termination, call the #kill method.

def startup_responders()
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
end

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
  rescue Exception=>e
    Raven.capture_exception(e)
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

          cmdline = "cds_run --route \"#{@routefile}\" #{@cdsarg} #{triggerfile}"
          @logger.debug("Commandline is #{cmdline}")
          @pid = spawn(cmdline)

          exitstatus = Process.wait @pid

          msg=FinishedNotification.new(@routename, exitstatus, GetLogfile(msg.id))
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
