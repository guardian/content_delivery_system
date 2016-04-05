Gem::Specification.new do |s|
  s.name        = 'elementallib'
  s.version     = '1.0'
  s.date        = '2014-08-11'
  s.summary     = "Elemental encoder interface for CDS"
  s.description = "Libraries for interfacing to the CDS datastore"
  s.authors     = ["Andy Gallagher"]
  s.email       = 'andy.gallagher@theguardian.com'
  s.files       = ["lib/Elemental/Elemental.rb", "lib/Elemental/Job.rb" ]
  s.homepage    =
    ''
  s.license       = 'GNM'
  s.add_runtime_dependency 'sqlite3', '>=1.3.0'
  s.add_runtime_dependency 'awesome_print', '>1.0'
end
