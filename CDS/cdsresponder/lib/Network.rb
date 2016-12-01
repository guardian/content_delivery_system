require 'webrick'
require 'HealthCheckServlet'

def startup_networkreceiver
  server = WEBrick::HTTPServer.new(:Port=>$options.port)
  server.mount('/healthcheck',HealthCheckServlet)
end
