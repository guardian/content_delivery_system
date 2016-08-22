Gem::Specification.new do |s|
  s.name        = 'cdslib'
  s.version     = '1.0'
  s.date        = '2010-04-28'
  s.summary     = "CDS/Datastore and CDS/Datastore-Episode5"
  s.description = "Libraries for interfacing to the CDS datastore"
  s.authors     = ["Andy Gallagher"]
  s.email       = 'andy.gallagher@theguardian.com'
  s.files       = ["lib/CDS/Datastore.rb","lib/CDS/Datastore-Episode5.rb", "lib/CDS/HLSUtils.rb"]
  s.homepage    =
    ''
  s.license       = 'GNM'
  s.add_runtime_dependency 'sqlite3', '>=1.3.0'
  s.add_runtime_dependency 'awesome_print', '>1.0'
end
