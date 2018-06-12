require "graphql/client"
require "graphql/client/http"
require 'pp'

require_relative('lib/github_graphql')


g = GitHubGraphQL.new(GitHubGraphQL.auth_token())
client = g.client()



BranchQuery = client.parse <<-'GRAPHQL'
query($after: String, $resultsize: Int!) {
  rateLimit {
    cost
    remaining
    resetAt
  }
  repository(owner: "KlickInc", name: "klick-genome") {
    refs(refPrefix: "refs/heads/", orderBy: {direction: DESC, field: TAG_COMMIT_DATE}, first: $resultsize, after: $after) {
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
        associatedPullRequests(first: 5, states: [OPEN]) {
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
                    login
                    createdAt
                  }
                }
              }
            }
            reviews(first: 10, states: [APPROVED, CHANGES_REQUESTED]) {
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
def collect_branches(query, end_cursor, all_branches = [])

  g = GitHubGraphQL.new(GitHubGraphQL.auth_token())
  client = g.client()

  # Shortcut during dev
  return all_branches if (all_branches.size() > 0)
  
  puts "Calling, currently have #{all_branches.size} branches"
  result = client.query(query, variables: {after: end_cursor, resultsize: 50})
  branches = result.data.repository.refs.nodes
  all_branches += branches
  paging = result.data.repository.refs.page_info
  if (paging.has_next_page) then
    collect_branches(query, paging.end_cursor, all_branches)
  else
    return all_branches
  end
end


result = collect_branches(BranchQuery, nil)
result.each do |n|
  puts n.to_h
end
