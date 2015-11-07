class FileObject
  attr_reader :path
  def initialize(path)
    @path = path
  end
  def work_to_do?(suffix)
    return !File.exists?(flag_path(suffix))
  end
  def get()
    File.read(@path)
  end
  def flag_path(suffix)
    "#{path}#{suffix}"
  end
  def mark_as_copied(suffix)
    File.open(flag_path(suffix), 'w') do |io|
      io.write('copied')
    end
  end
  def to_s()
    path
  end
  def modification_time
    File.mtime(@path)
  end
end

class FileStorage
  def initialize(_, path)
    @path = path
  end
  def glob(pattern)
    puts "globbing #{@path}/#{pattern}"
    Dir.glob("/#{@path}/#{pattern}").map{|path|FileObject.new(path)}
  end
  def close()
  end
end
