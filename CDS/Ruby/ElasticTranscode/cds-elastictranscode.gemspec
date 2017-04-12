
Gem::Specification.new do |s|
  s.name        = 'cds-elastictranscode'
  s.version     = '2.0.0'
  s.date        = DateTime.now.strftime("%Y-%m-%d")
  s.summary     = "Elastic transcode helpers for Content Delivery System"
  s.description = "Interfaces to Amazon's Elastic Transcoder"
  s.authors     = ["Andy Gallagher"]
  s.email       = 'andy.gallagher@theguardian.com'
  s.files       = ["lib/CDSElasticTranscode.rb",
                   "lib/filename_utils.rb",
  ]
  s.add_runtime_dependency 'aws-sdk-resources', '~> 2.9', '>=2.9.2'
  s.license       = 'GPL-3.0'
end
