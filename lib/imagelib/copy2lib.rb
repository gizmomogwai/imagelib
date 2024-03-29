#!/usr/bin/env ruby
# coding: utf-8

HOME = ENV['HOME']
OUT_DIR = "/Volumes/ImageLib/Pictures/ImageLib"
PATTERN = '**/*.{jpg,jpeg,JPG,JPEG,avi,AVI,wav,WAV,CR2,mp4,MOV,MP4}'
ERRORS = []

require 'fileutils'
require 'ruby-progressbar'
require 'yaml'
#require 'imagelib/mtp_storage'
require 'imagelib/file_storage'
require 'imagelib/http_storage'
require 'colorize'

class Copy
  class Result
    def initialize(filename, target, ok, cause = nil)
      @filename = filename
      @target = target
      @ok = ok
      @cause = cause
    end
    def self.positive(filename, destination)
      return Result.new(filename, destination, true)
    end
    def self.negative(filename, destination, cause)
      return Result.new(filename, destination, false, cause)
    end
    def to_s()
      return " OK : #{@filename} -> #{@target}".green if @ok
      return "NOK : #{@filename} (#{@cause})".red
    end
  end
  attr_reader :filename, :prefix, :creation_date, :target_path
  def initialize(file, prefix)
    @file = file
    @prefix = prefix
    #    @creation_date = File.mtime(filename)
    #    @target_path = sprintf("%s/%d/%02d/%d-%02d-%02d",
    #                           OUT_DIR,
    #                           @creation_date.year,
    #                           @creation_date.month,
    #                           @creation_date.year,
    #                           @creation_date.month,
    #                           @creation_date.day)
    #    @target_filename = "#{@target_path}/#{@prefix}#{File.basename(@filename)}"
    #    @flag_filename = "#{@filename}.#{ENV['LOGNAME']}"
  end

  def prepare(path)
    d = File.split(path).first
    FileUtils::mkdir_p(d)
  end

  def copy
    suffix = calc_suffix
    if (work_to_do?(suffix))
      begin
        data = @file.get()
        t = target_file_name(@file, data)
        prepare(t)
        File.write(t, data)
        @file.mark_as_copied(suffix)
        return Result.positive(@file.path, t)
      rescue StandardError => e
        puts e
        puts e.backtrace
        return Result.negative(@file.path, t, e)
      end
    end
  end

  def target_file_name(file, data)
    begin
      require 'exifr'
      exif = EXIFR::JPEG.new(StringIO.new(data))
      d = exif.date_time_original
    rescue StandardError => e
    end
    unless d
      d = file.modification_time
    end
    target_path = sprintf("%s/%d/%02d/%d-%02d-%02d",
                          OUT_DIR, d.year, d.month, d.year, d.month, d.day)
    File.join(target_path, "#{@prefix}#{File.basename(file.path)}")
  end

  def work_to_do?(suffix)
    return @file.work_to_do?(suffix)
  end

  def to_s
    return "#{@file} with #{prefix}"
  end
end

def collect_images(configs)
  images = []
  configs.each do |config|
    path = config['path']
    m = path.match(Regexp.new("(.*)://(.*?)/(.*)"))
    if m == nil
      puts "Skipping #{path}"
      next
    end

    clazz = m[1] + "Storage"
    clazz[0] = clazz[0].upcase
    handler = Object.const_get(clazz).new(m[2], m[3])
    begin
      files = handler.glob(PATTERN).sort{|i,j|i.path<=>j.path}
      puts "#{handler} globbed #{files.size} for #{PATTERN} on #{path}"
      files.each do |file|
        if !file.path.include?("trash")
          images << Copy.new(file, config['prefix'])
        end
      end
    rescue StandardError => e2
      puts e2
      e2.backtrace
    ensure
      handler.close()
    end
  end
  return images
end

def copy_images(images)
  progress = ProgressBar.create(title: "copy #{images.size} files", total: images.size, format: "%t %c / %C : %B Rate: %R %E")
  copied_images = Array.new
  images.each do | to_copy |
    progress.log("Working on #{to_copy}")
    res = to_copy.copy
    if res
      copied_images << res
    end
    progress.increment
  end
  progress.finish
  return copied_images
end

def process_commandline(args)
  configs = []
  if (args.size == 0)
    config_file_path = File.join(HOME, '.config', 'imagelib.yaml')
    configs = YAML::load_file(config_file_path)
    puts "Found configs: #{configs}"
  else
    i = 0
    while i < args.size
      path = args[i]
      prefix = args[i+1]
      configs << {'path' => path, 'prefix' => prefix}
      i = i + 2
    end
  end
  configs
end

def report_result(copied_images)
  puts "copied images: #{copied_images.size}".green
  copied_images.each do | i |
    puts "copied #{i}"
  end
end
def calc_suffix
  return ENV["OVERRIDE_LOGNAME"] || ENV["LOGNAME"]
end

def copy_to_lib(args)
  #  devices = MtpDevices.new
  #  device = devices.list.first
  #
  #  f = LibMtpBinding::File.new()
  #  f.clear()
  #  name = "test2.gizmo"
  #  mem = LibC.malloc(name.length + 1)
  #  mem.write_string(name)
  #  f[:parent] = 94
  #  f[:storage] = 0
  #  f[:filename] = mem
  #  f[:size] = 1
  #  f[:type] = 44
  #  puts "got device"
  #  res = f.send(device, "X")
  #  puts res
  #  LibMtpBinding::LIBMTP_Dump_Errorstack(device)
  #  exit 0

  suffix = ".#{calc_suffix}"
  puts "User: #{suffix}"
  configs = process_commandline(args)
  images = collect_images(configs)
  images = images.sort{ |a,b|
    a.filename <=> b.filename
  }
  images = images.select{ |copy|
    h = copy.work_to_do?(suffix)
    h
  }
  copied_images = copy_images(images)
  report_result(copied_images)
end
