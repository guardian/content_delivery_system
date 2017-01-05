
Gem::Specification.new do |s|
  s.name        = 'cdsresponder'
  s.version     = '2.0.0'
  s.date        = DateTime.now.strftime("%Y-%m-%d")
  s.summary     = "SQS queue responder to trigger CDS"
  s.description = "Consumes messages from SQS and triggers CDS with the result as a type of file, taking its config from DynamoDB"
  s.authors     = ["Andy Gallagher"]
  s.email       = 'andy.gallagher@theguardian.com'
  s.files       = ["lib/CDSResponder.rb",
                   "lib/ConfigFile.rb",
                   "lib/FinishedNotification.rb",
                   "lib/HealthCheckServlet.rb",
                   "lib/Network.rb"
                ]
  s.executables = ["cdsresponder.rb"]
  s.add_runtime_dependency 'aws-sdk-v1', '~> 1.66', '>=1.66.0'
  s.add_runtime_dependency 'trollop', '~> 2.1', '>=2.1.2'
  s.add_runtime_dependency 'json', '~> 1.8', '>=1.8.0'
  s.add_runtime_dependency 'certifi', '~> 2016.9', '>=2016.09.26'
  s.add_runtime_dependency 'webrick', '~> 1.3', '>=1.3.0'
  s.license       = 'GPL-3.0'
end
