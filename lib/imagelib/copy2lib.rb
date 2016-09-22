#!/usr/bin/env ruby
# coding: utf-8
HOME = ENV['HOME']
OUT_DIR = "#{HOME}/Pictures/ImageLib"
PATTERN = '**/*.{jpg,JPG,avi,AVI,wav,WAV,CR2,gizmo,mp4,MOV,MP4}'
require 'FileUtils'
require 'ruby-progressbar'
require 'yaml'
#require 'imagelib/mtp_storage'
require 'imagelib/file_storage'
require 'imagelib/http_storage'
require 'colorize'
ERRORS = []
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
    suffix = "#{ENV['LOGNAME']}"
    if (work_to_do?(suffix))
      begin
        data = @file.get()
        t = target_file_name(@file, data)
        prepare(t)
        File.write(t, data)
        puts "before mark"
        @file.mark_as_copied(suffix)
        puts "after mark"
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
      puts e
      puts e.backtrace
    end
    unless d
      puts "falling back to file modification time for #{file}"
      d = file.modification_time
    end
    target_path = sprintf("%s/%d/%02d/%d-%02d-%02d",
                          OUT_DIR, d.year, d.month, d.year, d.month, d.day)
    File.join(target_path, @prefix + File.basename(file.path))
  end

  def work_to_do?(suffix)
    return @file.work_to_do?(suffix)
  end

  def to_s
    return "#{@file} with #{prefix}"
  end
end

def collect_images(configs)
  puts "configs #{configs}"
  images = []
  configs.each do |config|
    puts "config #{config}"
    path = config['path']
    m = path.match(Regexp.new("(.*)://(.*?)/(.*)"))
    next unless m

    clazz = m[1] + "Storage"
    clazz[0] = clazz[0].upcase
    begin
      puts "trying to get #{clazz}"
      handler = Object.const_get(clazz).new(m[2], m[3])
      puts "got #{clazz}"
      begin
        files = handler.glob(PATTERN).sort{|i,j|i.path<=>j.path}
        puts "#{handler} globbed #{files.size} for #{PATTERN} on #{path}"
        puts files.map{|f|f.path}.join(', ')
        files.each do |file|
          images << Copy.new(file, config['prefix'])
        end
      rescue StandardError => e2
        puts e2
        e2.backtrace
      ensure
        puts "closing #{handler}"
        handler.close()
      end
    rescue StandardError => e
      puts e
      puts e.backtrace
    end
  end
  return images
end

def copy_images(images)
  progress = ProgressBar.create(:title => "copy #{images.size} files", :total => images.size, :format => '%t %c / %C : %B Rate: %R %E')
  copied_images = Array.new
  images.each do | to_copy |
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
    config_file_path = File.join(ENV['HOME'], '.imagelib')
    configs = YAML::load_file(config_file_path)
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

  suffix = ".#{ENV['LOGNAME']}"
  configs = process_commandline(args)
  images = collect_images(configs)
  images = images.sort{ |a,b|
    puts a
    puts b
    a.filename <=> b.filename
  }
  puts images
  images = images.select{ |copy|
    h = copy.work_to_do?(suffix)
    puts "work to do for #{copy}: #{h}"
    h
  }
  puts "images to do: #{images.size}"
  copied_images = copy_images(images)
  report_result(copied_images)
end
