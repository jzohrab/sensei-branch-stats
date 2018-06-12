require "graphql/client"
require "graphql/client/http"

class GitHubGraphQL

  TOKEN = 'GITHUB_GRAPHQL_API_TOKEN'
  SCHEMAFILE = File.join(File.dirname(__FILE__), 'schema.json')
  
  def get_configured_http()
    return GraphQL::Client::HTTP.new("https://api.github.com/graphql") do
      def headers(context)
        {
          "User-Agent" => "My Client",
          "Authorization" => "bearer #{ENV[GitHubGraphQL::TOKEN]}"
        }
      end
    end
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
