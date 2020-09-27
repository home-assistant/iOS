require "rdoc/task"
require "rake/testtask"
require "rubygems/package_task"
require "bundler/gem_tasks"
require "code_statistics"

require "rubygems"

task :default => [:test]

Rake::TestTask.new do |test|
  test.libs       = ["lib", "test"]
  test.test_files = FileList[ "test/tc_*.rb"]
  test.verbose    = true
  test.warning    = true
end

RDoc::Task.new do |rdoc|
  rdoc.rdoc_files.include( "README.rdoc", "INSTALL",
                           "TODO", "Changelog.md",
                           "AUTHORS", "COPYING",
                           "LICENSE", "lib /*.rb" )
  rdoc.main     = "README.rdoc"
  rdoc.rdoc_dir = "doc/html"
  rdoc.title    = "HighLine Documentation"
end

Gem::PackageTask.new(SPEC) do |package|
  # do nothing:  I just need a gem but this block is required
end
