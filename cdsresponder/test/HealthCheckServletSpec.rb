require 'rspec'
require 'HealthCheckServlet'
require 'webrick/httprequest'
require 'webrick/httpresponse'
require 'webrick/config'

describe 'HealthCheckServlet' do
  it 'should return 200 OK for a health ping' do
    cfg = WEBrick::Config::HTTP
    request = WEBrick::HTTPRequest.new(cfg)
    response = WEBrick::HTTPResponse.new(cfg)

    s = HealthCheckServlet.new(WEBrick::HTTPServer.new(:Port=>8910))
    s.do_GET(request,response)

    expect(response.status).to eq 200
    expect(response['Content-Type']).to eq 'text/plain'
    expect(response.body).to eq 'OK'
  end
end