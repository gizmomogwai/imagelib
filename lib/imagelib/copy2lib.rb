#!/usr/bin/env ruby
HOME = ENV['HOME']
OUT_DIR = "#{HOME}/Pictures/ImageLib"
PATTERN = '**/*.{jpg,JPG,avi,AVI,wav,WAV,CR2}'
require 'FileUtils'
require 'rubygems'
gem 'progressbar'
require 'progressbar'
require 'yaml'

class Copy
  attr_reader :filename, :prefix, :creation_date, :target_path
  def initialize(filename, prefix)
    @filename = filename
    @prefix = prefix
    @creation_date = File.mtime(filename)
    @target_path = sprintf("%s/%d/%02d/%d-%02d-%02d",
                           OUT_DIR,
                           @creation_date.year,
                           @creation_date.month,
                           @creation_date.year,
                           @creation_date.month,
                           @creation_date.day)
    @target_filename = "#{@target_path}/#{@prefix}#{File.basename(@filename)}"
    @flag_filename = "#{@filename}.#{ENV['LOGNAME']}"
  end

  def prepare
    FileUtils::mkdir_p(@target_path)
  end

  def copy
    if (work_to_do?)
      puts "#{@filename} -> #{@target_filename}"
      FileUtils::cp(@filename, @target_filename, :preserve=>true )
      File.open(@flag_filename, 'w') { |file| }
      return @target_filename
    end
  end

  def work_to_do?
    return !(File.exists?(@target_filename) or
             File.exists?(@flag_filename))
  end

  def to_s
    return "#{@filename} with #{prefix}"
  end
end


def collect_images(configs)
  images = []
  configs.each do |config|
    path = config['path'].strip
    files = Dir.glob("#{path}/#{PATTERN}")
    files.each do |file|
      images << Copy.new(file, config['prefix'])
    end
  end
  return images
end


def copy_images(images)
  progress = ProgressBar.new("copy #{images.length} files", images.size)
  copied_images = Array.new
  images.each do | copy |
    copy.prepare
    res = copy.copy
    if res
      copied_images << res
    end
    progress.inc
  end
  progress.finish
  return copied_images
end

def process_commandline(args)
  configs = []
  if (args.size == 0) then
    configs = YAML::load_file("#{HOME}/.imagelib")
  else
    i = 0
    while i < args.size
      path = args[i]
      prefix = args[i+1]
      configs << {'path' => path, 'prefix' => prefix}
      i = i + 2
    end
  end
end

def report_result(copied_images)
  puts "copied images: #{copied_images.size}"
  copied_images.sort.each do | i |
    puts "copied #{i}"
  end
end

def copy_to_lib(args)
  configs = process_commandline(args)
  images = collect_images(configs)
  images = images.sort{ |a,b| a.filename <=> b.filename }
  images = images.select{ |copy| copy.work_to_do? }
  copied_images = copy_images(images)
  report_result(copied_images)
end
