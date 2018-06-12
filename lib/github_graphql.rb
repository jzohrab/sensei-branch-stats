require 'graphql/client'
require 'graphql/client/http'
require 'yaml'


class GitHubGraphQL

  TOKEN = 'GITHUB_GRAPHQL_API_TOKEN'
  CREDSFILE = File.join(File.dirname(__FILE__), 'github_creds.yml')
  SCHEMAFILE = File.join(File.dirname(__FILE__), 'schema.json')

  # Reads the auth token from config file.  If not available, falls
  # back to environment.
  def self.auth_token()
    token = nil
    if File.exist?(CREDSFILE) then
      # puts "#{CREDSFILE} found"
      hsh = YAML.load_file(CREDSFILE)
      token = hsh[GitHubGraphQL::TOKEN]
    end
    token = ENV[GitHubGraphQL::TOKEN] if token.nil?
    raise "Missing token in env and creds file" if token.nil?
    token
  end


  def initialize(token)
    @token = token
  end


  def get_configured_http()
    h = GraphQL::Client::HTTP.new("https://api.github.com/graphql")
    headers = <<HERE
      def headers(context)
      {
        "User-Agent" => "My Client",
        "Authorization" => "bearer #{@token}"
      }
end
HERE
    h.instance_eval(headers)
    h
  end


  def get_schema()
    http = get_configured_http()
    schema = GraphQL::Client.load_schema(http)
  end


  def dump_schema(f)
    http = get_configured_http()
    GraphQL::Client.dump_schema(http, f)
  end


  def client()
    http = get_configured_http()
    schema = nil
    if (File.exist?(GitHubGraphQL::SCHEMAFILE))
      schema = GraphQL::Client.load_schema(GitHubGraphQL::SCHEMAFILE)
    else
      schema = GraphQL::Client.load_schema(http)
    end
    client = GraphQL::Client.new(schema: schema, execute: http)
    client
  end
  
end
