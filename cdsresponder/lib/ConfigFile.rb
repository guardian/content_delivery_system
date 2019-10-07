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
  def method_missing(name)
    raise KeyError, name unless @var.key?(name.to_s)
    @var[name.to_s]
  end #method_missing
end