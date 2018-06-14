require 'yaml'
require 'json'
require 'ostruct'

require_relative 'github_graphql'

class GitHubBranchQuery

    BranchQueryDefinition = GitHubGraphQL.new(GitHubGraphQL.auth_token()).client.parse <<-GRAPHQL
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

  def initialize()
    g = GitHubGraphQL.new(GitHubGraphQL.auth_token())
    @client = g.client()
  end


  def collect_branches(vars)
    $stdout.puts "Fetching branches from GitHub GraphQL, in sets of #{vars[:resultsize]} branches"
    result = collect_branches_iter(BranchQueryDefinition, vars, nil)
    return result
  end

  # Iterative recursion, collect results in all_branches array.
  def collect_branches_iter(query, vars, end_cursor, all_branches = [])
  
    # Shortcut during dev
    if vars[:stopafter] then
      $stdout.puts "  stopping early due to 'stopafter', have #{all_branches.size} branches"
      return all_branches if (all_branches.size() > vars[:stopafter].to_i)
    end
    
    $stdout.puts "  fetching (currently have #{all_branches.size} branches)"
  
    if end_cursor then
      vars[:after] = end_cursor
    end
    result = @client.query(query, variables: vars)
    # pp result
  
    all_branches += result.data.repository.refs.nodes
    paging = result.data.repository.refs.page_info
    if (paging.has_next_page) then
      collect_branches_iter(query, vars, paging.end_cursor, all_branches)
    else
      return all_branches
    end
  end
  
  
end  # class BranchQuery


