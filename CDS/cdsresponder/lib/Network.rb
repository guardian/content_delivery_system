require 'webrick'
require 'HealthCheckServlet'

def startup_networkreceiver(port)
  server = WEBrick::HTTPServer.new(:Port=>port)
  server.mount('/healthcheck',HealthCheckServlet)
end
