require 'webrick'
require 'logger'

#Simple webrick servlet to respond to an ELB healthcheck
class HealthCheckServlet <  WEBrick::HTTPServlet::AbstractServlet
  #Returns a 200 response and 'OK' in the body in response to a GET request
  def do_GET(request,response)
    response.status = 200
    response['Content-Type'] = 'text/plain'
    response.body = 'OK'
  end
end
