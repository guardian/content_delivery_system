require 'webrick'
require 'HealthCheckServlet'

def startup_networkreceiver(port)
  p port
  server = WEBrick::HTTPServer.new(:Port=>port)
  server.mount('/healthcheck',HealthCheckServlet)
  server
end
