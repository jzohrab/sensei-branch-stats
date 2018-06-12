require "graphql/client"
require "graphql/client/http"
require 'pp'

require_relative('lib/github_graphql')


# Iterative recursion, collect results in all_branches array.
def collect_branches(client, query, vars, end_cursor, all_branches = [])

  # Shortcut during dev
  if vars[:stopafter] then
    return all_branches if (all_branches.size() > vars[:stopafter].to_i)
  end
  
  # puts "Calling, currently have #{all_branches.size} branches"

  if end_cursor then
    vars[:after] = end_cursor
  end
  result = client.query(query, variables: vars)
  # pp result

  branches = result.data.repository.refs.nodes
  all_branches += branches
  paging = result.data.repository.refs.page_info
  if (paging.has_next_page) then
    collect_branches(client, query, vars, paging.end_cursor, all_branches)
  else
    return all_branches
  end
end


vars = {
  owner: 'KlickInc',
  repo: 'klick-genome',
  resultsize: 50
}

g = GitHubGraphQL.new(GitHubGraphQL.auth_token())
client = g.client()

queryfile = File.join(File.dirname(__FILE__), 'queries', 'branches_and_pull_requests.graphql')
BranchQuery = client.parse(File.read(queryfile))
  
result = collect_branches(client, BranchQuery, vars, nil)
results_hashed = result.map { |n| n.to_h }

outfile = File.join(File.dirname(__FILE__), 'github_graphql_responses', 'response.yml')
File.open(outfile, 'w') do |file|
   file.write results_hashed.to_yaml
end 
