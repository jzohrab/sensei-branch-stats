# Can post to the wiki via API
# Ref https://wiki.senseilabs.com/YJpOYOjtcp6/api
#
# api/Page
# You can PATCH to the above endpoint. You must pass 3 fields: ID (the
# Page ID), Title, and Content. The Title cannot be null or whitespace
# only.

require 'json'
require 'net/http'
require 'net/https'
require 'uri'
require 'optparse'

$stdout.sync = true


module BranchStatistics

  class WikiPost

    def initialize(token)
      raise "Missing token" if token.nil?
      @token = token
    end
    
    def post(pageid, title, filename)

      raise 'Missing arg' if [pageid, title, file].any? { |a| a.nil? }
      raise "Missing file #{filename}" if !File.exist?(filename)

      content = File.read(filename)
      req_data = {
        'ID' => pageid,
        'TITLE' => title,
        'Content' => content
      }
      patch_data = URI.encode_www_form(req_data)

      uri = URI.parse('https://wiki.senseilabs.com/api/Page')
      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true
      https.verify_mode=OpenSSL::SSL::VERIFY_NONE

      header = {'Content-Type' => 'application/x-www-form-urlencoded', 'Authorization' => @token}
      request = Net::HTTP::Patch.new(uri, header)
      response = https.start do |h|
        h.request(request, patch_data)
      end

      puts "Code: #{response.code}; Body: #{response.body}"
      raise "Error posting to wiki: #{response.code}, #{response.body}" if response.code.to_i != 200
      puts "Page updated"

    end

  end # class

end  # module
