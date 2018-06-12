require "graphql/client"
require "graphql/client/http"
require 'pp'

require_relative('lib/github_graphql')


g = GitHubGraphQL.new(GitHubGraphQL.auth_token())
client = g.client()



BranchQuery = client.parse <<-'GRAPHQL'
query($after: String, $resultsize: Int!, $owner: String!, $repo: String!) {
  rateLimit {
    cost
    remaining
    resetAt
  }
  repository(owner: $owner, name: $repo) {
    refs(refPrefix: "refs/heads/", orderBy: {direction: ASC, field: ALPHABETICAL}, first: $resultsize, after: $after) {
      pageInfo {
        startCursor
        hasNextPage
        endCursor
      }
      nodes {
        name
        target {
          ... on Commit {
            oid
            committedDate
            committer {
              email
            }
            messageHeadline
            status {
              state
            }
          }
        }
        associatedPullRequests(first: 2, states: [OPEN]) {
          nodes {
            number
            title
            url
            headRefName
            baseRefName
            createdAt
            updatedAt
            additions
            deletions
            mergeable
            labels(first: 10) {
              nodes {
                name
              }
            }
            assignees(first: 10) {
              edges {
                node {
                  email
                }
              }
            }
            reviewRequests(first: 10) {
              nodes {
                requestedReviewer {
                  ... on Team {
                    name
                  }
                  ... on User {
                    name: login   # Aliasing so User and Team have same field names.
                  }
                }
              }
            }
            reviews(first: 50) {
              nodes {
                createdAt
                author {
                  login
                }
                submittedAt
                updatedAt
                state
              }
            }
          }
        }
      }
    }
  }
}
GRAPHQL


# Iterative recursion, collect results in all_branches array.
def collect_branches(query, vars, end_cursor, all_branches = [])

  g = GitHubGraphQL.new(GitHubGraphQL.auth_token())
  client = g.client()

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
    collect_branches(query, vars, paging.end_cursor, all_branches)
  else
    return all_branches
  end
end


vars = {
  owner: 'KlickInc',
  repo: 'klick-genome',
  resultsize: 50
}

## vars = {
##   owner: 'jeff-zohrab',
##   repo: 'demo_gitflow',
##   resultsize: 50
## }

result = collect_branches(BranchQuery, vars, nil)
results_hashed = result.map { |n| n.to_h }

outfile = File.join(File.dirname(__FILE__), 'github_graphql_responses', 'response.yml')
File.open(outfile, 'w') do |file|
   file.write results_hashed.to_yaml
end 
