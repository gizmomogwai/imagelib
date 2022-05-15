require 'faraday'
require 'faraday_middleware'
require "addressable/uri"

class HttpFile
  attr_reader :path
  def initialize(client, path, all)
    @client = client
    @path = path
    @all = all
  end
  def work_to_do?(suffix)
    res = @path.end_with?(suffix)
    return false if res

    res = @all.include?(flag_path(suffix))
    return !res
  end
  def flag_path(suffix)
    "#{@path}.#{suffix}"
  end
  def get
    response = @client.get(Addressable::URI.encode("/files/#{@path}"))
    return response.body
  end
  def mark_as_copied(suffix)
    res = @client.post(Addressable::URI.encode("/files/#{@path}"), {filename: @path, suffix: suffix})
    if res.status != 200
      raise 'problems while markme'
    end
  end
  def to_s
    "HttpFile(#{@path})"
  end
  def modification_time
    m = Regexp.new(".*PANO_(....)(..)(..)_(..)(..).*").match(@path)
    m = m || Regexp.new(".*VID_(....)(..)(..)_(..)(..).*").match(@path)
    m = m || Regexp.new(".*IMG_(....)(..)(..)_(..)(..).*").match(@path)
    m = m || Regexp.new(".*Google Photos/(....)(..)(..)_(..)(..).*").match(@path)
    m = m || Regexp.new(".*PXL_(....)(..)(..)_(..)(..).*").match(@path)
    if m
      res = Time.new(m[1], m[2], m[3], m[4], m[5])
      return res
    end
    res = Time.now
    raise "Could not get time for #{self}"
    # return res
  end
end

class HttpStorage
  def initialize(id, path)
    @id = id
    @path = path[0...-1]
    @client = Faraday.new(url: "http://#{@id}:4567") do |faraday|
      faraday.request :url_encoded
      faraday.headers = {"accept-encoding": "identity"}
      # faraday.response :logger
      faraday.response :json, :content_type => 'application/json'
      faraday.adapter Faraday.default_adapter
    end
  end
  def glob(pattern)
    response = @client.get '/index'
    all = response.body
    pp all
    return all
             .select{|f|
               File.fnmatch(pattern, f, File::FNM_EXTGLOB) && !f.include?('/.thumbnails/')
             }
             .map{|i|HttpFile.new(@client, i, all)}
  end
  def close
  end
end
