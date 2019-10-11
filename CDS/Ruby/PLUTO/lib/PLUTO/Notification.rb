require 'net/http'
#require 'net/http/post/multipart' #GEM DEPENDENCY ON MULTIPART-POST-2.0.0
require 'awesome_print'
require 'base64'

#notification type constants
NT_COMMISSION = 1
NT_PROJECT = 2
NT_MASTER = 3
NT_PUBLISH = 4

#severity type constants
ST_INFO = 1
ST_ATTENTION = 2
ST_URGENT = 3

class Credentials
    attr_accessor :user
    attr_accessor :password
    attr_accessor :server
    attr_accessor :https

    def initialize(user,password, server, https=false)
        @user=user
        @password=password
        @server=server
        @https = https
    end #def initialize

end #class Credentials

class Notification
    attr_accessor :message
    attr_accessor :type
    attr_accessor :severity
    attr_accessor :url
    attr_accessor :object_type
    attr_accessor :object_id
    attr_accessor :expires
    attr_accessor :debug
    attr_accessor :users
    attr_accessor :groups

    def initialize(message,type,severity: "info",url:nil,
                   object_type:nil, object_id:nil, users:[], groups:[], expires:nil)
        if(message==nil)
            raise ArgumentError,"You need to specify a message to make a notification"
        end
        if(type==nil)
            raise ArgumentError,"You need to specify a notification type"
        end
        if(severity==nil)
            raise ArgumentError,"You need to specify a severity"
        end
        unless(expires==nil or expires.is_a?(DateTime))
            raise ArgumentError,"If you specify the expires argument it must be a DateTime"
        end
        @message=message
        @type=type
        @severity=severity
        @url=url
        @object_type=object_type
        @object_id=object_id
        @expires=expires
        @debug=false
        @users=users
        @groups=groups

    end #def initialize

    #sever here is the CANTEMO server, not Vidispine!!
    #this can raise HTTP exceptions
    def send!(creds)
        unless(creds.is_a?(Credentials))
            raise ArgumentError,"You need to pass a PLUTO::Credentials object to send!"
        end

        headers = {}
        headers['Authorization'] = 'Basic ' + Base64.encode64("#{creds.user}:#{creds.password}").chop
        uri = URI("#{creds.https ? "https" : "http"}://#{creds.server}/notifications/api/")

        if(@url==nil and @object_id!=nil and @object_type!=nil)
            @url="#{creds.https ? "https" : "http"}://#{creds.server}/#{@object_type.downcase}/#{@object_id}/"
        end

        hashdata = {
            'message'=>@message,
            'type'=>@type,
            'severity'=>@severity,
            'url'=>@url,
            'object_type'=>@object_type,
            'object_id'=>@object_id
        }
        if(@expires)
            hashdata['expires']=@expires.strftime("%Y-%m-%dT%H:%M:%S")
        end
        if(@users)
            hashdata['username']=@users #.join(' ')
        end
        if(@groups)
            hashdata['group']=@groups #.join(' ')
        end

        if(@debug)
            ap hashdata
        end
        bodycontent=URI.encode_www_form(hashdata)

        #result = Net::HTTP.post_form(uri,hashdata)
        result = self._sendto(uri,bodycontent,headers)

        unless(result.is_a?(Net::HTTPSuccess))
            raise StandardError,"Unable to communicate with PLUTO: #{result.class}: #{result.body} #{result.inspect}"
        end
    end #def send!


    def _sendto(uri,bodycontent,headers)
        begin
            result=nil
            if(@debug)
                puts "connecting to #{uri}"
            end

            #FIXME: how to enable HTTPS here?
            Net::HTTP.start(uri.host,uri.port,:use_ssl => uri.scheme == 'https') do |http|
                #result=http.request Net::HTTP::Post.new(uri,bodycontent,headers)
                result=http.post(uri.path, bodycontent, headers)
            end
            if(result.is_a?(Net::HTTPMovedPermanently) and result['Location'])
                if(@debug)
                    puts "redirecting to #{result['location']}"
                end
                uri=URI.parse(result['Location'])
            end
        end while(result.is_a?(Net::HTTPMovedPermanently))

        result
    end
end #class Notification