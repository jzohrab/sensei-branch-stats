require 'yaml'

CREDS_KEY = 'GITHUB_GRAPHQL_API_TOKEN'
token = ENV[CREDS_KEY]
puts "Have token = #{token}"

github_creds_file = File.join(File.dirname(__FILE__), 'github_creds.yml')
if (token.nil? and File.exist?(github_creds_file)) then
  hsh = YAML.load_file(github_creds_file)
  token = hsh[CREDS_KEY]
end

puts token

raise "Missing #{CREDS_KEY}" if token.nil?

