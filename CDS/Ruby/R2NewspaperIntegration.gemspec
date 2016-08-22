Gem::Specification.new do |s|
  s.name        = 'R2NewspaperIntegration'
  s.version     = '1.0'
  s.date        = '2010-04-28'
  s.summary     = "Ruby class to access the bits of the Guardian's R2 Newspaper Integration API that Multimedia need"
  s.description = "Library for accessing the Newspaper Integration api"
  s.authors     = ["Andy Gallagher"]
  s.email       = 'andy.gallagher@theguardian.com'
  s.files       = ["lib/R2NewspaperIntegration/R2.rb"]
  s.homepage    =
    ''
  s.license       = 'GNM'
  s.add_runtime_dependency 'mime-types', '>2.0'
  s.add_runtime_dependency 'awesome_print', '>1.0'
end
