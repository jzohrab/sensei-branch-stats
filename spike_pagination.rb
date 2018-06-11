require "graphql/client"
require "graphql/client/http"

$stdout.sync = true
require 'pp'

$token = ARGV[0]
if ($token.nil? || $token == '') then
  raise "Missing token"
end


module GitHubGraphQL
  HTTP = GraphQL::Client::HTTP.new("https://api.github.com/graphql") do
    def headers(context)
      {
        "User-Agent" => "My Client",
        "Authorization" => "bearer #{$token}"
      }
    end
  end  

  # Fetch latest schema on init (makes a network request)
  Schema = GraphQL::Client.load_schema(HTTP)
  Client = GraphQL::Client.new(schema: Schema, execute: HTTP)
end


BranchQuery = GitHubGraphQL::Client.parse <<-'GRAPHQL'
query($after: String) {
  repository(owner: "KlickInc", name: "klick-genome") {
    refs(refPrefix: "refs/heads/", orderBy: {direction: DESC, field: TAG_COMMIT_DATE}, first: 50, after: $after) {
      edges {
        node {
          ... on Ref {
            name
          }
        }
      }
      pageInfo {
        startCursor
        hasNextPage
        endCursor
      }
    }
  }
}
GRAPHQL


# Iterative recursion, collect results in all_branches array.
def collect_branches(query, end_cursor, all_branches = [])
  puts "Calling, currently have #{all_branches.size} branches"
  result = GitHubGraphQL::Client.query(query, variables: {after: end_cursor})
  branches = result.data.repository.refs.edges.map { |n| n.node.name }
  all_branches += branches
  paging = result.data.repository.refs.page_info
  if (paging.has_next_page) then
    collect_branches(query, paging.end_cursor, all_branches)
  else
    return all_branches
  end
end


puts collect_branches(BranchQuery, nil)
