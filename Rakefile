require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

task :make_coffee do
  cups = 2
  puts "Made #{cups} cups of coffee. Shakes are gone."
end


desc 'Default: run unit tests.'
task :default => :test

desc 'Test the triplify plugin.'
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.libs << 'test'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end

desc 'Generate documentation for the triplify plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'Triplify'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
