require 'PLUTO/Notification'

RSpec.describe Credentials, "#initialize" do
  it "should hold the passed credentials" do
    creds = Credentials.new("fred","password","myserver.com",true)
    expect(creds.server).to eq "myserver.com"
    expect(creds.https).to eq true
    expect(creds.user).to eq "fred"
    expect(creds.password).to eq "password"
  end
end

RSpec.describe Notification, "#_sendto" do
  it "should send the relevant body to the requested host" do
    noti = Notification.new("test","test")

    stub_request(:post, "https://someserver:443/somepath/to/data").
        with(
            body: "bodycontent is here",
            headers: {
                'Accept'=>'*/*',
                'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
                'Content-Type'=>'text/plain',
                'User-Agent'=>'Ruby'
            }).
        to_return(status: 200, body: "", headers: {})

    result = noti._sendto(URI("https://someserver:443/somepath/to/data"),"bodycontent is here",{"Content-Type"=>"text/plain"})

    expect(result.is_a?(Net::HTTPOK)).to eq true
  end

  it "should follow permanent redirects" do
    noti = Notification.new("test","test")

    stub_request(:post, "https://someserver:443/somepath/to/data").
        with(
            body: "bodycontent is here",
            headers: {
                'Accept'=>'*/*',
                'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
                'Content-Type'=>'text/plain',
                'User-Agent'=>'Ruby'
            }).
        to_return(status: 301, body: "", headers: {'Location'=>"https://otherserver:443/other/path"})

    stub_request(:post, "https://otherserver:443/other/path").
        with(
            body: "bodycontent is here",
            headers: {
                'Accept'=>'*/*',
                'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
                'Content-Type'=>'text/plain',
                'User-Agent'=>'Ruby'
            }).
        to_return(status: 200, body: "redirected_endpoint", headers: {})

    result = noti._sendto(URI("https://someserver:443/somepath/to/data"),"bodycontent is here",{"Content-Type"=>"text/plain"})

    expect(result.is_a?(Net::HTTPOK)).to eq true
    expect(result.body).to eq "redirected_endpoint"
  end
end

RSpec.describe Notification, "#send!" do
  it "should send the given message as an encoded form as https if requested" do
    creds = Credentials.new(user="fred",password="fredspassword",server="notificationserver.org.int",https=true)

    noti = Notification.new("test","test", url: "http://link-to=object",object_type: "item", object_id: "12345")

    stub_request(:post, "https://notificationserver.org.int/notifications/api/").
        with(
            body: "message=test&type=test&severity=info&url=http%3A%2F%2Flink-to%3Dobject&object_type=item&object_id=12345&&",
            headers: {
                'Accept'=>'*/*',
                'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
                'Authorization'=>'Basic ZnJlZDpmcmVkc3Bhc3N3b3Jk',
                'User-Agent'=>'Ruby'
            }).
        to_return(status: 200, body: "", headers: {})

    noti.send!(creds)
  end

  it "should send the given message as an encoded form as http if not requested" do
    creds = Credentials.new(user="fred",password="fredspassword",server="notificationserver.org.int")

    noti = Notification.new("test","test", url: "http://link-to=object",object_type: "item", object_id: "12345")

    stub_request(:post, "http://notificationserver.org.int/notifications/api/").
        with(
            body: "message=test&type=test&severity=info&url=http%3A%2F%2Flink-to%3Dobject&object_type=item&object_id=12345&&",
            headers: {
                'Accept'=>'*/*',
                'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
                'Authorization'=>'Basic ZnJlZDpmcmVkc3Bhc3N3b3Jk',
                'User-Agent'=>'Ruby'
            }).
        to_return(status: 200, body: "", headers: {})

    noti.send!(creds)
  end

  it "should raise if the server does not respond with a 2xx" do
    creds = Credentials.new(user="fred",password="fredspassword",server="notificationserver.org.int",https=true)

    noti = Notification.new("test","test", url: "http://link-to=object",object_type: "item", object_id: "12345")

    stub_request(:post, "https://notificationserver.org.int/notifications/api/").
        with(
            body: "message=test&type=test&severity=info&url=http%3A%2F%2Flink-to%3Dobject&object_type=item&object_id=12345&&",
            headers: {
                'Accept'=>'*/*',
                'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
                'Authorization'=>'Basic ZnJlZDpmcmVkc3Bhc3N3b3Jk',
                'User-Agent'=>'Ruby'
            }).
        to_return(status: 500, body: "", headers: {})

    expect {
      noti.send!(creds)
    }.to raise_error(StandardError)
  end
end