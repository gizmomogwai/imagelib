require "bundler/gem_tasks"

task :default => [:install]

desc 'create rvm wrapper'
task :create_wrapper do
  version = File.read('.ruby-version').strip
  gemset = File.read('.ruby-gemset').strip
  sh "rvm wrapper #{version}@#{gemset} copy2lib"
end
