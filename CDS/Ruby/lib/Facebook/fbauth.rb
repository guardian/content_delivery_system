class FBError < StandardError
end

class HTTPError < FBError
  #code
end

class InternalError < FBError
  
end

class AccessDenied < FBError
end

module FBAuthorise
  require 'json'
  require 'net/http'
  attr :client_id,:client_secret
  
  def _accountsForApp
    _accounts(@client_id)  
  end #_accountsForApp
  
  def _accounts(pageid)
    uri = URI("https://graph.facebook.com/v2.3/#{pageid}/accounts?access_token=#{@client_id}|#{@client_secret}")
    
    Net::HTTP.start(uri.host,uri.port) do |http|
      req = Net::HTTP::Get.new(uri)
      req.add_field('Host','graph.facebook.com')
      
      response = http.request(req)
      
      if response.code==404
        raise InternalError, "Endpoint for #{uri} not found"
      end
      
      if response.code<200 or response.code>299
        raise HTTPError, "Error #{response.code} for #{uri}: #{response.body}"
      end
    end
    
    data = JSON.parse(response.body)
    data['data'] #this should be a hash containing id,login_url,access_token
  end #def _accounts
end #module FBAuthorise

class FBUser
  attr :user_id,:token
  
  def initialize(user_id: nil)
    @user_id=user_id
  end
end
