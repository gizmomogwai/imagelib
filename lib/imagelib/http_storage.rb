require 'faraday'

class HttpStorage
  def initialize(id, path)
    puts 1
    @id = id
    puts 2
    @path = path
    puts 3
    @client = Faraday.new(url: @path) do |faraday|
      faraday.request :url_encoded
      faraday.response :logger
      faraday.adapter Faraday.default_adapter
    end
    puts 4
  end
  def glob(pattern)
    puts "globbing '#{pattern}'"
    puts "asking the server"
    response = @client.get '/index'
    puts response
    return []
  end
  def close
  end
end
