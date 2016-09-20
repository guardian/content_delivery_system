#!/usr/bin/env ruby

require 'aws-sdk-v1'
require 'json'
require 'optparse'
require 'pp'
require 'json'
require 'raven'

Raven.configure do |config|
    config.dsn = "***REMOVED***"
end

class ConfigFile
    attr_accessor :var

    def initialize(filename)
        unless File.exists?(filename)
            raise "Requested configuration file #{filename} does not exist."
        end
        @var={}
        File.open(filename,"r"){ |f|
            f.each_line { |line|
                row=line.match(/^(?<name>[^=]+)=(?<value>.*)$/)
                @var[row['name']]=row['value']
            }
        }
    end
end

class FinishedNotification
attr_accessor :exitcode
attr_accessor :log
attr_accessor :routename

def initialize(routename,exitcode,log)
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

class CDSResponder
attr_accessor :url
attr_accessor :isexecuting
attr_accessor :should_finish

def initialize(arn,routename,arg,notification)
	@routename=routename
	@cdsarg=arg
	@notification_arn=notification
	matchdata=arn.match(/^arn:aws:sqs:([^:]*):([^:]*):([^:]*)/);
	@region=matchdata[1];
	@acct=matchdata[2];
	@name=matchdata[3];
	@url="https://sqs.#{@region}.amazonaws.com/#{@acct}/#{@name}";
	@sqs=AWS::SQS::new(:region=>'eu-west-1');
	@q=@sqs.queues[@url]
	@isexecuting=1;
    @should_finish=false
    
	if notification!=nil 
		@sns=AWS::SNS.new(:region=>'eu-west-1')
		@notification_topic=@sns.topics[notification]
	end

	@threadref=Thread.new {
		ThreadFunc();
	}
end

def GetUniqueFilename(path)
	filebase=@routename.gsub(/[^\w\d]/,"_")
	filename=path+'/'+filebase+".xml"
	n=0;
	while(Pathname(filename).exist?) do
		n=n+1
		filename=path+'/'+filebase+"-"+n.to_s()+".xml"
	end
	filename
end

def GetRouteContent
	ddb=AWS::DynamoDB.new(:region=>$options[:region])
	table=ddb.tables[$cfg.var['routes-table']]
	table.hash_key=[ :routename,:string ]
	item=table.items[@routename]
	item.attributes['content']
end

#Download the route name given from the DynamoDB table and return the local filename
def DownloadRoute
	filename=GetUniqueFilename('/etc/cds_backend/routes')
	
	puts "Got filename #{filename} for route file\n"
	
	File.open(filename, 'w'){ |f|
		f.write(GetRouteContent())
	}
	filename
end

#Output the message as a trigger file
def OutputTriggerFile(contents,id)
	File.open(id+".xml", 'w'){ |f|
		f.write(contents)
	}
	id+".xml"
end

def GetLogfile(name)
	#filename = @logpath+"/"+name+".log"
	contents = ""
	File.open(@logpath+"/"+name+".log", 'r'){ |f|
		contents=f.read()
	}
	contents
rescue
	puts "Unable to read log from filename\n"
end

def ThreadFunc

while @isexecuting do
	@q.poll { |msg|
	begin #start a block to catch exceptions
		#puts "Received message:\n";
		#puts "\t#{msg.body}\n";
		@routefile=DownloadRoute()
		@commandline="cds_run --route \"#{@routefile}\" #{@cdsarg}="

		trigger_content=msg.body
		begin
			jsonobject = JSON.parse(msg.body) #if we're subscribed to an SNS queue we get a JSON object
			if jsonobject['Type'] == 'Notification'
				trigger_content = jsonobject['Message']
			end
		rescue JSON::JSONError
			print "Message on queue is not JSON"
			trigger_content=msg.body
		end
		puts trigger_content
	
		triggerfile=OutputTriggerFile(trigger_content,msg.id)
		#FIXME: should not be using static db credentials! should be in dynamodb somewhere.
		cmd=@commandline + triggerfile + " --logging-db=***REMOVED*** --db-host=***REMOVED*** --db-login=cdslogger --db-pass=***REMOVED*** --logging-id=#{msg.id}"
		system(cmd)

		msg=FinishedNotification.new(@routename,$?.exitstatus,GetLogfile(msg.id))
		@notification_topic.publish(msg.to_json)
	
	rescue Exception => e
		puts e.message
		puts e.backtrace.inspect
		begin
			@notification_topic.publish({'status'=>'error','message'=>e.message,'trace'=>e.backtrace}.to_json)
		rescue Exception=>e
			puts "Error passing on error message: #{e.message}"
		end

	ensure	
		File.delete(triggerfile)
		File.delete(@routefile)
	end	#end block to catch exceptions
	}
end #while @isexecuting

end #def threadfunc

def join
@threadref.join
#File.delete(@routefile)
end #def join

end #class CDSResponder

### START MAIN

Raven.capture do
    begin
    #Process any commandline options
    $options={:configfile=>'/etc/cdsresponder.conf',:region=>'UNKNOWN'}
    OptionParser.new do |opts|
        opts.banner="Usage: cdsresponder.rb [--config=/path/to/config.file] [--region=aws-region]"

        opts.on("-c","--config CONFIGFILE", "Path to the configuration file.  This should contain the following:",
                    "   configuration-table={dynamodb table to use for configuration}",
                    "\troutes-table={dynamodb table to use for the routes content}",
                    "\tregion={AWS region to use for SQS and DynamoDB",
                    "\taccess-key={AWS access key} [Optional; default behaviour is to attempt connection via AWS roles",
                    "\tsecret-key={AWS secret key} [Optional; as above") do |cfg|
            $options.configfile=cfg
        end

        opts.on("-r","--region [REGION]","AWS region to connect to") do |r|
            $options.region=r
        end
    end #OptionParser

    #Read in the configuration file.  cfg is declared as a global variable ($ prefix)
    begin
        $cfg=ConfigFile.new($options[:configfile])
    rescue Exception=>e
        raise "Unable to load configuration file: #{e.message}.  Please consult the documentation, the online cdsconfig configuration tool or run with the -h option, for more information"
        #Raven.capture_exception(e)
        #exit 1
    end

    #If we still don't have a region to work in, use the default...
    if $options[:region] == 'UNKNOWN'
        if $cfg.var['region']
            $options[:region]=$cfg.var['region']
        else
            $options[:region]='eu-west-1'
        end
    end

    puts "Commandline options:"
    p $options
    puts "Loaded config:"
    p $cfg

    sqs=AWS::SQS.new(:region=>$options[:region]);
    ddb=AWS::DynamoDB.new(:region=>$options[:region]);

    #table=ddb.tables['workflowmaster-cds-responder']
    table=ddb.tables[$cfg.var['configuration-table']]
    if !table or table==''
        raise "Unable to connect to the table #{$cfg.var['configuration-table']}.  Has this been set up yet by the system administrator?"
    end

    table.hash_key = ['queue-arn',:string]

    responders = Hash.new;

    table.items.each do |item|
            begin
        puts item.hash_value
            item.attributes.each_key do |key|
                    puts "\t#{key} => #{item.attributes[key]}\n";
            end
        for i in 1..item.attributes['threads']
            responder=CDSResponder.new(item.attributes['queue-arn'],item.attributes['route-name'],"--input-"+item.attributes['input-type'],item.attributes['notification'])
            #responders.push(responder);
            responders[item.attributes['queue-arn']] = responder
        end

        rescue
            puts "Responder failed to start up for #{item.attributes['queue-arn']}\n";
            next 
        puts responder.url
        end
    end

    responders.each {|name,resp|
        puts "checking threads..."
        resp.join
    }

    #rescue
    #	print "Terminating program...\n"
    #ensure
    #	responders.each {|resp|
    #		resp.isexecuting=0
    #		resp.join
    #	}
    end
end #raven.capture
