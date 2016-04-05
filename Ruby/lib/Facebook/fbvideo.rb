require 'Facebook/fbauth'
require 'mime/types'
require 'cgi'
require 'awesome_print'

class FacebookVideo
  require 'net/http'
  require 'net/http/post/multipart' #requires multipart-post
  attr_accessor :filepath,:user,:token
  attr_accessor :title,:description,:category,:embeddable
  
  def initialise(filepath, token, user)
    @filepath=filepath
    @token=token
    @user=user
  end
  
  def upload!
    raise ArgumentError, "No filepath" if(@filepath.nil?)
    raise ArgumentError, "File #{@filepath} does not exist" if(not File.exists?(@filepath))
    #raise ArgumentError, "No token" if(@token.nil?)
    raise ArgumentError, "Need to specify an FBUser object in user=" if(not @user.is_a?(FBUser))
    
    if @token.nil?
      token = user.token
    else
      token = @token
    end

    args = []
    args << "access_token=#{token}"
    args << "title=" + CGI.escape(@title) if(@title)
    args << "description=" + CGI.escape(@description) if(@description)
    args << "content_category=" + CGI.escape(@category) if(@category)
    args << "embeddable=true" if(@embeddable)
    url = URI("https://graph.facebook.com/#{@user.user_id}/videos?#{args.join("&")}")
    
    ap url
    
    request = Net::HTTP::Post::Multipart.new(url.path,
                                             "source"=>UploadIO.new(File.new(@filepath),MIME::Types.type_for(@filepath),File.basename(@filepath))
                                             )
    response = Net::HTTP.start(url.host, url.port) do |http|
      http.request(request)
    end #Net::HTTP
    
    response.value()  #raise an exception if it failed
    
  end
  
end