#!/usr/bin/env ruby

#This method performs an update of the given video (specified as the current media file) to YouTube.
#It expects the following arguments:
# <client_secrets>secrets_file.json - An authorised client_secrets.json file from Google.  This should contain an authorisation to use the YouTube Data API and also identifies which channel the video is uploaded to, in confunction with the local authorisation. Expected to be under /etc/cds_backend/keys, but an absolute path can also be specified.
# <auth_cache>cachefile.json - A json file that the method can output the tokens that it receives to.  Does not have to exist when the method is run, and is updated whenever the tokens are updated.  Expected to be under /etc/cds_backend/keys, but an absolute path can also be specified.
# <cache_max_age>nnn - update the cache if it's older than this number of hours
# <private_key>/path/to/keyfile - [OPTIONAL] If using a service account, the path to the private key to grant it access
# <passphrase>blah - [OPTIONAL] If using a service account, the passphrase to decrypt the private key above
# <service_account>id - [OPTIONAL] Specify this option to use a Google API service account to connect to the YouTube service.  You need to specify the account id here (the one that looks like an email address (@developer.gserviceaccount.com), from Google Cloud console), as well as the private key file and a passphrase to decrypt said key
# <title>blah - [OPTIONAL] - use this value for the video title. Substitutions are encouraged, e.g. {meta:title}.
# <description>blah - [OPTIONAL] - use this value for the video description. Substitutions are encouraged, e.g. {meta:description}.
# <category>blah - [OPTIONAL] use this value for the video category. Substitutions are encouraged, e.g. {meta:category}. If the category is not a valid YouTube category, then a default will be used.
# <category_id>nnn - [OPTIONAL] - bypass the internal category mapping and specify an ID directly. Substitutions are encouraged, e.g. {meta:category_id}
# <category_default>blah - [OPTIONAL] use this as a default category name, if a category key cannot be found or is not valid. If not specifed, defaults to "People & Blogs".
# <access>{public|private|unlisted} - the ensure that the access policy for the video is set as such. You can set this from the data$store by using a substitution , e.g. {meta:yt_access_policy} sets according to the 'yt_access_policy'
# <owner_account>blah - [OPTIONAL] specifies that the content should be uploaded on behalf of the given account.  This may fail on certain types of account. It sets the 'onBehalfOfContentOwner' field, which Google#'s documentation states "is intended exclusively for YouTube content partners". You can set this from the data$store by using a substitution. If not provided, it defaults to the owner of the credentials used to log in.
# <owner_channel>blah - [OPTIONAL] specified that the content should be uploaded to the given channel.  This may fail on certain types of account. It sets the 'onBehalfOfContentOwnerChannel' field, which Google#'s documentation states "is intended exclusively for YouTube content partners". You can set this from the data$store by using a substitution.
# <auto_levels/> - [OPTIONAL] Asks YouTube to try to enhance the brightness and colour.
# <notify_subscribers/> - [OPTIONAL] Asks YouTube to notify subscribers to the channel about the upload
# <stabilize/> - [OPTIONAL] Asks YouTube to try to apply image stabilisation
# <embeddable/> - [OPTIONAL] Specifies that the video should be embeddable
# <no_public_stats/> - [OPTIONAL] Specifies that stats should be hidden to the public
# <publish_at>{timestamp} - [OPTIONAL] Asks YouTube to only publish at a given time . You can set this from the data$store by using a substitution
# <license_type>{creativeCommon|youtube} - [Optional] Tells YouTube to apply the relevant license type to the content. You can set this from the data$store by using a substitution
# <recording_date>{timestamp} - [OPTIONAL] Set the given value as the recording date.You can set this from the data$store by using a substitution 
# <gps_coords>{lat}:{long} - [OPTIONAL] Set the given latitude/longitude as the location where the media was recorded. You can set this from the data$store by using a substitution 

#END DOC

#Based on code from https://developers.google.com/youtube/v3/code_samples/ruby
require 'google/api_client'
require 'google/api_client/client_secrets'
require 'json'
require 'launchy'
require 'thin'
require 'date'
require 'rubygems'
require 'google/api_client'
require 'awesome_print'
#require 'FileUtils'

require 'CDS/Datastore'

#INTERNAL PARAMETERS
# This OAuth 2.0 access scope allows an application to upload files to the
# authenticated user's YouTube channel, but doesn't allow other types of access.
YOUTUBE_READ_WRITE_SCOPE = 'https://www.googleapis.com/auth/youtube.upload'
YOUTUBE_PARTNER_SCOPE = 'https://www.googleapis.com/auth/youtubepartner'
#YOUTUBE_ADMIN_SCOPE = 'https://www.googleapis.com/auth/youtube'
YOUTUBE_API_SERVICE_NAME = 'youtube'
YOUTUBE_API_VERSION = 'v3'
max_download_attempts = 5
$category_cache_file="/var/cache/cds_backend/youtube_category_list.json"
#END INTERNAL PARAMETERS

#This code implements requesting login credentials, and may be moved into a seperate authorisation program.
RESPONSE_HTML = <<stop
<html>
  <head>
    <title>OAuth 2 Flow Complete</title>
  </head>
  <body>
    You have successfully completed the OAuth 2 flow. Please close this browser window and return to your program.
  </body>
</html>
stop

FILE_POSTFIX = '-oauth2.json'

# Small helper for the sample apps for performing OAuth 2.0 flows from the command
# line. Starts an embedded server to handle redirects.
class CommandLineOAuthHelper

  def initialize(scope,filename=nil)
		puts "Using provided filename #{filename} for authorisation credentials." if(filename!=nil)

    credentials = Google::APIClient::ClientSecrets.load(filename)
    @authorization = Signet::OAuth2::Client.new(
      :authorization_uri => credentials.authorization_uri,
      :token_credential_uri => credentials.token_credential_uri,
      :client_id => credentials.client_id,
      :client_secret => credentials.client_secret,
      :redirect_uri => credentials.redirect_uris.first,
      :scope => scope
    )
  end

  # Request authorization. Checks to see if a local file with credentials is present, and uses that.
  # Otherwise, opens a browser and waits for response, then saves the credentials locally.
  def authorize
    credentialsFile = $0 + FILE_POSTFIX

    if File.exist? credentialsFile
      File.open(credentialsFile, 'r') do |file|
        credentials = JSON.load(file)
        @authorization.access_token = credentials['access_token']
        @authorization.client_id = credentials['client_id']
        @authorization.client_secret = credentials['client_secret']
        @authorization.refresh_token = credentials['refresh_token']
        @authorization.expires_in = (Time.parse(credentials['token_expiry']) - Time.now).ceil
        if @authorization.expired?
          @authorization.fetch_access_token!
          save(credentialsFile)
        end
      end
    else
      auth = @authorization
      url = @authorization.authorization_uri().to_s
      server = Thin::Server.new('0.0.0.0', 8080) do
        run lambda { |env|
          # Exchange the auth code & quit
          req = Rack::Request.new(env)
          auth.code = req['code']
          auth.fetch_access_token!
          server.stop()
          [200, {'Content-Type' => 'text/html'}, RESPONSE_HTML]
        }
      end

      Launchy.open(url)
      server.start()

      save(credentialsFile)
    end

    return @authorization
  end

  def save(credentialsFile)
    File.open(credentialsFile, 'w', 0600) do |file|
      json = JSON.dump({
        :access_token => @authorization.access_token,
        :client_id => @authorization.client_id,
        :client_secret => @authorization.client_secret,
        :refresh_token => @authorization.refresh_token,
        :token_expiry => @authorization.expires_at
      })
      file.write(json)
    end
  end
end

class InvalidCredentials < StandardError
end

def youtube_connect
puts "Attempting to connect to YouTube..."
begin
	#OK, now that's out of the way let's get a connection to YouTube...
	client = Google::APIClient.new(:application_name => 'gnm-youtube-uploader', :application_version => '1.0')
	#youtube = client.discovered_api(YOUTUBE_API_SERVICE_NAME, YOUTUBE_API_VERSION)
	youtube = nil
	
	if ENV['service_account']
		puts "Using server key credentials from #{ENV['private_key']} with passphrase."
		#load credentials for server->server interactions (see https://code.google.com/p/google-api-ruby-client/wiki/ServiceAccounts)
		key=Google::APIClient::KeyUtils.load_from_pkcs12($store.substitute_string(ENV['private_key']), $store.substitute_string(ENV['passphrase']))
		#asserter=Google::APIClient::JWTAsserter.new($store.substitute_string(ENV['service_account']),YOUTUBE_READ_WRITE_SCOPE,key)
		#use the loaded key to authorise the client object
		#client.authorization = asserter.authorize()
		File.open(ENV['client_secrets'],"r") { |file|
			creds=JSON.load(file)
			if(ENV['debug'])
				puts "DEBUG: Got credentials:"
				ap creds
			end
            
			raise InvalidCredentials, "No credentials present in #{ENV['client_secrets']}" if(not creds)
			raise InvalidCredentials, "Credentials in #{ENV['client_secrets']} not valid" if(not creds['web'] or not creds['web']['client_email'])
            
			client.authorization = Signet::OAuth2::Client.new(
				:token_credential_uri => 'https://accounts.google.com/o/oauth2/token',
  				:audience => 'https://accounts.google.com/o/oauth2/token',
				:scope => YOUTUBE_PARTNER_SCOPE,
				:issuer => creds['web']['client_email'],
			    :signing_key => key
			)
			client.authorization.fetch_access_token!
			youtube = client.discovered_api(YOUTUBE_API_SERVICE_NAME, YOUTUBE_API_VERSION)
		}
	else
		puts "Using standard OAuth credentials (this may pop up a browser)"
		auth_util = CommandLineOAuthHelper.new(YOUTUBE_READ_WRITE_SCOPE,ENV['client_secrets'])
		#use the OAuth credentials to authorise the client object
		client.authorization = auth_util.authorize()
		youtube = client.discovered_api(YOUTUBE_API_SERVICE_NAME, YOUTUBE_API_VERSION)
	end
	
	#Right, now we should be clear to do something interesting.
	puts "Authorised to YouTube"
	if(ENV['debug'])
#		ap youtube
		#puts youtube.discovery_document
#		puts youtube.inspect
#		ap youtube.to_h
#		ap youtube.discovered_methods
		#ap youtube.discovery_document
	end
	
	return client, youtube
#TODO: exception handling

end


end

class CategoryNotFound < StandardError
end

class InvalidCacheFile < StandardError
end

class CategoryMapper

def initialize(cache_file)
@cache_file=cache_file
@cached_document=nil
end

#this function performs the actual mapping
def id_from_name(name)
if(@cached_document==nil)
	max_age=12
	begin
		if(ENV['cache_max_age'])
			max_age=ENV['cache_max_age'].to_i
		end
	rescue Exception => e
		puts "-WARNING: Unable to parse requested cache age #{ENV['cache_max_age']} hours: #{e.message}. Defaulting to 12 hours"
	end
	
	download_attempts=0

	unless(File.exists?(@cache_file))
		self.download_data!
	end
	
	begin
		if(self.cache_age() > max_age)
			self.download_data!
			download_attempts+=1
		end
	rescue StandardError=>e
		puts "-WARNING: #{e.message}"
	end
	
	begin
		File.open(@cache_file,mode="r"){ |f|
			puts "Waiting for shared lock on cache file #{@cache_file}..."
			f.flock(File::LOCK_SH)
			puts "Parsing JSON..."
			@cached_document=JSON.parse(f)
			f.flock(File::LOCK_UN)
		}
		puts "Cached file read in"
	rescue JSON::JsonError=>e
		puts "-WARNING: Unable to parse cache file #{@cache_file} (download attempts: #{download_attempts}): #{e.message}"
		if(download_attempts<max_download_attempts)
			download_attempts+=1
			puts "Re-attempting download."
			self.download_data!
			retry
		end
		raise InvalidIndex,"-ERROR:  Unable to parse cache file #{@cache_file} (download attempts: #{download_attempts}): #{e.message}"
	end
end

#@cached_document should now be a hash containing the YouTube mapping details
@cached_document['items'].each{ |item|
	if(ENV['debug'])
		puts "\tDEBUG: CategoryMapper::id_from_name: got name #{item['snippet']['title']}"
		ap item
	end

	if(item['snippet']['title'].downcase==name.downcase)
		return item['id']
	end
}
raise InvalidCategory, "Could not find the requested category #{name} in the cached index file #{@cache_file}"
end

def cache_age
return Time.now-self.last_updated
end

def last_updated
unless(File.exists?(@cache_file))
	raise StandardError,"No cache file exists at present."
end
return File.new(@cache_file).mtime
end

def download_data!
puts "Attempting to refresh category list..."
begin
	client, youtube = youtube_connect()
	
	ap youtube.to_h
	videos_catlist_response=client.execute!(
		:api_method => youtube.videoCategories.list,
		:parameters => {
			:part => "id,snippet",
			:regionCode => "GB"
		}
	)
	
	if(ENV['debug'])
		puts "DEBUG: Youtube responded:"
		ap videos_catlist_response
	end

	puts "Category list retrieved. Waiting for exclusive lock on cache file #{@cache_file}..."
	begin
		FileUtils.mkpath(File(@cache_file).dirname)
	rescue Exception=>e
		puts "-WARNING: Problem creating directory for cache file: #{e.message}"
	end
	File.open(@cache_file, File::RDWR|File::Creat, 0644) { |f|
		f.flock(File::LOCK_EX)
		f.rewind
		f.truncate(0)
		f.write(videos_catlist_response)
		f.flock(File::LOCK_UN)
	}
rescue InvalidCredentials=>e
	puts "-ERROR: #{e.message}"
		ap e.backtrace if(ENV['debug'])
rescue Exception=>e
	puts "-ERROR: Unable to refresh category list: #{e.message}"
	ap e.backtrace if(ENV['debug'])
end

end #def download_data

end #class CategoryMapper
class ArgumentError < StandardError
end

def assert_args(argnames)
	argnames.each do |name|
		unless(ENV[name])
			raise ArgumentError, "-ERROR: You need to define the argument <#{name}> in the routefile."
		end
	end
end #def assert_args

def errorReportContains(reportInfo,fields)
	begin
		reportInfo['error']['errors'].each do |error|
			fields.each {|k,v|
				if error[k] and error[k] == v
		return true
				end
			}
		end #errors.each
		return false
	rescue IndexError=>e
		$stderr.puts "-WARNING: indexerror #{e.message} occurred while scanning error report"
		return false
	end #exception handling

end #errorReportContains

#START MAIN
puts "Starting up..."

#Process commandline args
opts={}

#throw an exception if these aren't defined
if ENV['service_account']
	assert_args(['service_account','private_key','passphrase'])
else
	assert_args(['client_secrets','auth_cache'])
end

$store=Datastore.new('youtube_upload')

#set default values that are then over-ridden by routefile
body={
	:snippet => {
		:title => "title",
		:description => "description",
		:tags => "Guardian News & Media",
		:categoryId => 22
	},
	:status => {
		:privacyStatus => 'private',
		:embeddable=>false
	}
}

params={
	'uploadType'=>'multipart',
	:autoLevels=>false,
	:notifySubscribers=>false,
	:stabilize=>false
}

puts "Mapping arguments..."

mapper=CategoryMapper.new($category_cache_file)

title="title"
if ENV['title']
	body[:snippet][:title]=$store.substitute_string(ENV['title'])
	# <title_key>blah - [OPTIONAL] - use this key (in the meta section) for the video title. Defaults to 'title'.
end
description="description"
if ENV['description']
	body[:snippet][:description]=$store.substitute_string(ENV['description'])
	# <description_key>blah - [OPTIONAL] - use this key (in the meta section) for the video description. Defaults to 'description'.
end
category="People & Blogs"
if ENV['category']
	begin
		raise CategoryNotFound,"Category download is currently broken"
		body[:snippet][:categoryId]=mapper.id_from_name($store.substitute_string(ENV['category']))
	rescue CategoryNotFound=>e
		$stdout.puts "-WARNING: Category #{ENV['category']} was not found in the YouTube category list. Defaulting to category 22 (People & Blogs). Consult #{$category_cache_file} for the list of acceptable category names"
	rescue InvalidCacheFile=>e
		$stdout.puts "-ERROR: Unable to retrieve a valid category index. Defaulting to category 22 (People & Blogs). Consult the log for more information"
	end
	# <category_key>blah - [OPTIONAL] use this key (in the meta section) for the video category. Defaults to 'category'. If the category is not a valid YouTube category, then a default will be used.
end
# <category_default>blah - [OPTIONAL] use this as a default category name, if a category key cannot be found or is not valid. If not specifed, defaults to "People & Blogs".
if ENV['category_id']
    body[:snippet][:categoryId]=$store.substitute_string(ENV['category_id'])
end

body[:status][:privacyStatus]="private"
if ENV['access']
	body[:status][:privacyStatus]=$store.substitute_string(ENV['access'])
	# <access>{public|private|unlisted} - the ensure that the access policy for the video is set as such. You can set this from the data$store by using a substitution , e.g. {meta:yt_access_policy} sets according to the 'yt_access_policy'
end

if ENV['owner_account']
    owner_acct = $store.substitute_string(ENV['owner_account'])
    parts = owner_acct.split('|')
    owner_acct = parts[0] if(parts.length > 1)
	  params[:onBehalfOfContentOwner]=owner_acct
	# <owner_account>blah - [OPTIONAL] specifies that the content should be uploaded on behalf of the given account.  This may fail on certain types of account. It sets the 'onBehalfOfContentOwner' field, which Google#'s documentation states "is intended exclusively for YouTube content partners". You can set this from the data$store by using a substitution. 
end


if ENV['owner_channel']
    owner_chl = $store.substitute_string(ENV['owner_channel'])
    parts = owner_chl.split('|')
    owner_chl = parts[0] if(parts.length > 1)
    
	params[:onBehalfOfContentOwnerChannel]=owner_chl
	# <owner_channel>blah - [OPTIONAL] specified that the content should be uploaded to the given channel.  This may fail on certain types of account. It sets the 'onBehalfOfContentOwnerChannel' field, which Google#'s documentation states "is intended exclusively for YouTube content partners". You can set this from the data$store by using a substitution.
end

auto_levels=false
if ENV['auto_levels']
	unless(ENV['auto_levels']==0 or ENV['auto_levels']=='false' or ENV['auto_levels']=='no')
		params[:autoLevels]=true
	end
end
# <auto_levels/> - [OPTIONAL] Asks YouTube to try to enhance the brightness and colour.

notify_subscribers=false
if ENV['notify_subscribers']
	unless(ENV['notify_subscribers']==0 or ENV['notify_subscribers']=='false' or ENV['notify_subscribers']=='no')
		params[:notifySubscribers]=true
	end
end
# <notify_subscribers/> - [OPTIONAL] Asks YouTube to notify subscribers to the channel about the upload

stabil=false
if ENV['stabilize']
	unless(ENV['stabilize']==0 or ENV['stabilize']=='false' or ENV['stabilize']=='no')
		params[:stabilize]=true
	end
end
if ENV['stabilise']
	unless(ENV['stabilise']==0 or ENV['stabilise']=='false' or ENV['stabilise']=='no')
		params[:stabilize]=true
	end
end
# <stabilize/> - [OPTIONAL] Asks YouTube to try to apply image stabilisation

#body[:status][:embeddable]=false
if ENV['embeddable']
	unless(ENV['embeddable']==0 or ENV['embeddable']=='false' or ENV['embeddable']=='no')
		body[:status][:embeddable]=true
	end
end
# <embeddable/> - [OPTIONAL] Specifies that the video should be embeddable


if ENV['no_public_stats']
	unless(ENV['no_public_stats']==1 or ENV['no_public_stats']=='true' or ENV['no_public_stats']=='yes')
		body[:status][:publicStatsViewable]=false
	end
end
# <no_public_stats/> - [OPTIONAL] Specifies that stats should be hidden to the public

pubtime=nil
if ENV['publish_time']
	body[:status][:publishAt]=DateTime.parse($store.substitute_string(ENV['publish_at']))
	# <publish_at>{timestamp} - [OPTIONAL] Asks YouTube to only publish at a given time . You can set this from the data$store by using a substitution
end

license=""
if ENV['license_type']
	body[:status][:license]=$store.substitute_string(ENV['license_type'])
end
# <license_type>{creativeCommon|youtube} - [Optional] Tells YouTube to apply the relevant license type to the content. You can set this from the data$store by using a substitution


recdate=nil
if ENV['recording_date']
	#see if this automatically recognises 'now'
	body[:recordingDetails][:recordingDate]=DateTime.parse($store.substitute_string(ENV['recording_date']))
end
# <recording_date>{timestamp} - [OPTIONAL] Set the given value as the recording date.You can set this from the data$store by using a substitution

gps_coords=""
if ENV['gps_coords']
	params=$store.substitute_string(ENV['gps_coords']).scan(/[\d\.]+/)
	body[:recordingDetails][:location][:latitude]=params[0].to_f
	body[:recordingDetails][:location][:longitude]=params[1].to_f
	# <owner_channel>blah - [OPTIONAL] specified that the content should be uploaded to the given channel.  This may fail on certain types of account. It sets the 'onBehalfOfContentOwnerChannel' field, which Google#'s documentation states "is intended exclusively for YouTube content partners". You can set this from the data$store by using a substitution.
end
# <gps_coords>{lat}:{long} - [OPTIONAL] Set the given latitude/longitude as the location where the media was recorded. You can set this from the data$store by using a substitution 

puts "Argument mapping complete. Data that will get sent to YouTube:"
ap body
ap params

params[:part] = body.keys.join(',')

if(ENV['debug'])
	puts "DEBUG: Raw data that will get sent to youTube:"
	ap params
end

puts "Attempting to connect to YouTube..."
begin
	client, youtube=youtube_connect()
	
	video_insert_response=client.execute!(
		:api_method => youtube.videos.insert,
		:body_object => body,
		:media =>Google::APIClient::UploadIO.new(ENV['cf_media_file'],'video/*'),
		:parameters => params
	)
	
	if(ENV['debug'])
		puts "Data returned from YouTube:"
		ap video_insert_response
	end

	puts "Outputting id to datastore key meta:youtube_id"
	$store.set('meta','youtube_id',video_insert_response.data.id)

	puts "+SUCCESS: Video with title #{video_insert_response.data.snippet.title} was uploaded to YouTube with id #{video_insert_response.data.id}."

rescue Google::APIClient::TransmissionError => e
	$stdout.puts "-WARNING: Unable to transmit to YouTube: #{e.result.body}"
	report = JSON.parse(e.result.body)
	if errorReportContains(report,{'reason'=>"invalidCategoryId"}) and body[:snippet][:categoryId]!=25
	  $stdout.puts "INFO: Error was an invalid category ID. Re-trying with default category ID 25 (News & Politics)"
	  body[:snippet][:categoryId] = 25
	  retry
	end
	
	$stdout.puts "-ERROR: Unable to recover error: #{e.result.body}"
	exit 1

rescue StandardError=>e
	$stderr.puts "-ERROR: #{e.message}"
	$stderr.puts e.backtrace.inspect
	exit 1
end
exit 0


