require "bundler/gem_tasks"

task :default => [:install]

desc 'create rvm wrapper'
task :create_wrapper do
  sh "rvm wrapper 2.3.1@imagelib copy2lib"
end
