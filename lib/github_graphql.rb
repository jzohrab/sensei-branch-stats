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


  class CachingHTTP < GraphQL::Client::HTTP
    def initialize(uri, token)
      @token = token
      super(uri)
    end

    def headers(context)
      {
        "User-Agent" => "My Client",
        "Authorization" => "bearer #{@token}"
      }
    end

    def execute(document:, operation_name: nil, variables: {}, context: {})
      cache_file = "GitHub_#{variables.values().join('-')}.cache"
      cachepath = File.join(File.dirname(__FILE__), 'cache', cache_file)
      result = get_cached_result(cachepath)
      if !result.nil? then
        $stdout.puts "  using cached results in #{cache_file}"
        return result
      end
      ret = super  # Calls the super method with same signature and args.
      File.open(cachepath, 'w') { |f| f.write ret.to_json }
      ret
    end

    def get_cached_result(cachefile)
      return nil if !File.exist?(cachefile)
      age_in_seconds = (Time.now - File.stat(cachefile).mtime).to_i
      return nil if (age_in_seconds > 30 * 60)
      JSON.parse(File.read(cachefile))
    end

  end


  def initialize(token)
    @token = token
    @http = CachingHTTP.new("https://api.github.com/graphql", @token)
  end

  def get_schema()
    schema = GraphQL::Client.load_schema(@http)
  end


  def dump_schema(f)
    GraphQL::Client.dump_schema(@http, f)
  end


  def client()
    schema = nil
    if (File.exist?(GitHubGraphQL::SCHEMAFILE))
      schema = GraphQL::Client.load_schema(GitHubGraphQL::SCHEMAFILE)
    else
      $stdout.puts "Fetching schema from GitHub ... (NOTE: run 'rake dump_schema' to optimize)"
      schema = GraphQL::Client.load_schema(@http)
    end
    client = GraphQL::Client.new(schema: schema, execute: @http)
    client
  end
  
end
