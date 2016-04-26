require 'ffi'
require 'stringio'

module LibC
  extend FFI::Library
  ffi_lib FFI::Library::LIBC

  # memory allocators
  attach_function :malloc, [:size_t], :pointer
#  attach_function :calloc, [:size_t], :pointer
#  attach_function :valloc, [:size_t], :pointer
#  attach_function :realloc, [:pointer, :size_t], :pointer
#  attach_function :free, [:pointer], :void

  # memory movers
#  attach_function :memcpy, [:pointer, :pointer, :size_t], :pointer
  #  attach_function :bcopy, [:pointer, :pointer, :size_t], :void
end # module LibC

module LibMtpBinding

  class DeviceEntry < FFI::Struct
    layout :vendor, :string,
           :vendor_id, :ushort,
           :product, :string,
           :product_id, :ushort,
           :flags, :uint
  end

  class RawDevice < FFI::Struct
    layout :device, DeviceEntry,
           :bus_location, :uint32,
           :number, :uint8
  end

  class Folder < FFI::ManagedStruct
    layout :id, :uint,
           :parent, :uint,
           :storage, :uint,
           :name, :string,
           :sibling, :pointer,
           :child, :pointer

    def initialize(ptr, root=false, parent_path=nil)
      super(ptr)
      @root = root
      @parent_path = parent_path
    end

    def self.release(ptr)
      LibMtpBinding::LIBMTP_destroy_folder_t(ptr) if root
    end

    def traverse(level = 0, &block)
      block.call(self, level)
      recurse(self[:child], false, path, level + 1, &block)
      recurse(self[:sibling], @root, @parent_path, level, &block)
    end

    def recurse(what, root, path, level, &block)
      return if what.null?
      f = Folder.new(what, root, path)
      f.traverse(level, &block)
    end

    def path
      n = self[:name]
      @root ? "/#{n}" : "#{@parent_path}/#{n}"
    end
  end

  class File < FFI::Struct
    layout :id, :uint,
           :parent, :uint,
           :storage, :uint,
           :filename, :pointer,
           :size, :uint64,
           :mod_time, :long,
           :type, :uint,
           :next, :pointer

    def self.release(ptr)
      LIBMTP_destroy_file_t(ptr)
    end
    def get(device)
      res = StringIO.new
      p = Proc.new do |device_params, user_data, to_consume, data, consumed|
        res.write(data.read_string_length(to_consume))
        consumed.put_uint32(0, to_consume)
        0
      end
      h = LibMtpBinding::LIBMTP_Get_File_To_Handler(device, self[:id], p, nil, nil, nil)
      puts h
      raise 'could not receive' if h != 0
      res.string
    end
    def send(device, to_send)
      p = Proc.new do |params, user_data, wanted, data, got|
        puts "params #{params}"
        puts "user_data #{user_data}"
        puts "wanted #{wanted}"
        puts "data #{data}"
        puts "got #{got}"
        #puts "to_send #{to_send.class} #{to_send}"
        todo = [wanted, to_send.length].min
        data.write_bytes(to_send, 0, todo)
        to_send = to_send[todo..-1]
        got.put_uint32(0, todo)
        0
      end
      puts "send_file_from_handler"
      puts device
      puts p
      puts self
      h = LibMtpBinding::LIBMTP_Send_File_From_Handler(device, p, nil, self, nil, nil)
      puts "send_file_from_handler: #{h}"
      h
    end
  end

  extend FFI::Library
  ffi_lib 'libmtp'

  callback :data_put_function, [:pointer, :pointer, :uint, :pointer, :pointer], :uint16
  callback :data_get_function, [:pointer, :pointer, :uint32, :pointer, :pointer], :uint16
  callback :progress_function, [:uint64, :uint64, :pointer], :int

  attach_function :LIBMTP_Detect_Raw_Devices, [:pointer, :pointer], :int
  attach_function :LIBMTP_Open_Raw_Device, [:pointer], :pointer
  attach_function :LIBMTP_destroy_folder_t, [:pointer], :void
  attach_function :LIBMTP_new_file_t, [], :pointer
  attach_function :LIBMTP_Get_File_To_Handler, [:pointer, :uint, :data_put_function, :pointer, :pointer, :pointer], :int
  attach_function :LIBMTP_Send_File_From_Handler, [:pointer, :data_get_function, :pointer, :pointer, :pointer, :pointer], :int
  attach_function :LIBMTP_destroy_file_t, [:pointer], :void
  attach_function :LIBMTP_Init, [], :void
  attach_function :LIBMTP_Get_First_Device, [], :pointer
  attach_function :LIBMTP_Get_Connected_Devices, [:pointer], :int
  attach_function :LIBMTP_Get_Manufacturername, [:pointer], :string
  attach_function :LIBMTP_Get_Modelname, [:pointer], :string
  attach_function :LIBMTP_Get_Serialnumber, [:pointer], :string
  attach_function :LIBMTP_Get_Friendlyname, [:pointer], :string
  attach_function :LIBMTP_Release_Device, [:pointer], :void
  attach_function :LIBMTP_Reset_Device, [:pointer], :int
  attach_function :LIBMTP_Delete_Object, [:pointer, :uint], :int
  attach_function :LIBMTP_Get_Filelisting_With_Callback, [:pointer, :progress_function, :pointer], :pointer
  attach_function :LIBMTP_Get_Folder_List, [:pointer], :pointer
  attach_function :LIBMTP_Dump_Errorstack, [:pointer], :void
end


class FS < Hash
  def initialize(device, h)
    folder = LibMtpBinding::Folder.new(h)
    @folders = {}
    folder.traverse do |f, level|
      @folders[f[:id]] = f
      self[f.path] = f
    end
    require 'ruby-progressbar'
    pb = ProgressBar.create(:title => 'usb transfer', :format => '%t %j%% %b%i %a / %E')
    progress = Proc.new do |done, todo, user_data|
      pb.total = todo
      pb.progress = done
    end

    file = LibMtpBinding::File.new(LibMtpBinding::LIBMTP_Get_Filelisting_With_Callback(device, progress, nil))
    pb.finish
    puts
    while true
      folder_path = ""
      parent_id = file[:parent]
      parent = @folders[parent_id]
      folder_path = parent.path if parent

      file_path = File.join(folder_path, file[:filename].read_string())
      puts file_path
      self[file_path] = file
      h = file[:next]
      break if h == nil
      file = LibMtpBinding::File.new(h)
    end
  end

  def glob(pattern)
    res = []
    keys.each do |path|
      res << path if File.fnmatch(pattern, path, File::FNM_EXTGLOB)
    end
    res
  end
end

class MtpFile
  attr_reader :path
  def initialize(device, fs, path)
    @device = device
    @fs = fs
    @path = path
  end
  def work_to_do?(suffix)
    @fs.glob(@path + suffix).size == 0
  end
  def get()
    @fs[@path].get(@device)
  end
  def mark_as_copied(suffix)
    puts "mark_as_copied (#{suffix} #{path})"
    d, base = File.split(@path)
    name = base + suffix
    f = LibMtpBinding::File.new()
    f.clear()
    mem = LibC.malloc(name.length + 1)
    mem.write_string(name)
    puts d
    puts base
    puts name
    puts @fs[d][:id]
    f[:parent] = @fs[d][:id]
    f[:storage] = 0
    f[:filename] = mem
    f[:size] = 1
    f[:type] = 44
    res = f.send(@device, "X")
  end
  def delete()
    LibMtpBinding::LIBMTP_Delete_Object(@device, @fs[@path][:id])
  end
  def to_s
    "MtpFile(#{@path})"
  end
  def modification_time()
    d = Time.at(@fs[path][:mod_time])
    d
  end
end

class MtpStorage
  def initialize(device_id, path)
    @path = path
    LibMtpBinding.LIBMTP_Init()
    @device = LibMtpBinding::LIBMTP_Get_First_Device()
    raise 'device not found' if @device.null?
    @fs = FS.new(@device, LibMtpBinding::LIBMTP_Get_Folder_List(@device))
  end
  def glob(pattern)
    @fs.glob(pattern).map{|path|MtpFile.new(@device, @fs, path)}
  end
  def close()
    # LibMtp::release_device(@device)
  end
end
#
#def delete_gizmos()
#  mtp_storage = MtpStorage.new("device", "DCIM")
#  files = mtp_storage.glob("**/*.gizmo")
#  puts files
#  files.each do |f|
#    f.delete()
#  end
#end
#def check_mark_as_copied()
#  mtp_storage = MtpStorage.new("device", "DCIM")
#  files = mtp_storage.glob("**/*.gizmo")
#  puts files
#  f = files.first
#  puts f
#  data = f.get()
#  puts data
#end
#
#def copy_first_file()
#  mtp_storage = MtpStorage.new("device", "DCIM")
#  files = mtp_storage.glob("**/*.jpg")
#  f = files.first
#  data = f.get()
#
#  require 'exifr'
#  exif = EXIFR::JPEG.new(StringIO.new(data))
#  d = exif.date_time_original
#  puts d
#  require 'imagelib/copy2lib.rb'
#  c = Copy.new(f, 'ttt')
#  c.copy()
#  mtp_storage
#end

#begin
#mtp_storage = check_mark_as_copied
#mtp_storage = copy_first_file
#mtp_storage = delete_gizmos
#rescue Exception => e
#  puts e
#  puts e.backtrace
#ensure
#  mtp_storage.close()
#end

class MtpDevices
  def initialize()
    LibMtpBinding.LIBMTP_Init()
  end

  def list()
    list = FFI::MemoryPointer.new(:pointer, 1)
    count = FFI::MemoryPointer.new(:int, 1)
    res = LibMtpBinding::LIBMTP_Detect_Raw_Devices(list, count)
    raise "problems detecting raw devices" if res != 0

    count = count.read_int
    puts "#{count} devices"
    (0...count).map do |i|
      p = list.get_pointer(i)
      puts "pointer: #{p}"
      ptr = LibMtpBinding::LIBMTP_Open_Raw_Device(p)
      LibMtpBinding::DeviceEntry.new(ptr)
    end
  end

  def find(product_id)
    list.select{|device|device[:device][:product_id] == product_id}
  end
end

