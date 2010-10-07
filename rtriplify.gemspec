Gem::Specification.new do |s|
  s.name = %q{rtriplify}
  s.version = "0.0.0"
  s.date = %q{2007-09-03}
  s.authors = ["Nico Patitz"]
  s.email = %q{nico.patitz@gmx.de}
  s.summary = %q{a ruby clone of triplify}
  s.homepage = %q{http://www.triplify.org/}
  s.description = %q{a ruby clone of triplify. it can provide rdf data out of your existing database}
  s.files = %w(install.rb uninstall.rb README MIT-LICENSE ) + Dir.glob('rails/**/*.rb')+Dir.glob('lib/**/*.yml')+ Dir.glob('lib/**/*.rb')
  s.require_paths      = %w(lib)
end
