require "graphql/client"
require "graphql/client/http"
require 'pp'

require_relative('lib/github_graphql')


g = GitHubGraphQL.new(GitHubGraphQL.auth_token())
client = g.client()



BranchQuery = client.parse <<-'GRAPHQL'
{

  # Check usage stats
  rateLimit{
    cost
    remaining
    resetAt
  }

  # Get repo
  repository(owner: "KlickInc", name: "klick-genome") {

    # Get first two branches
    refs(refPrefix: "refs/heads/", orderBy: {direction: DESC, field: TAG_COMMIT_DATE}, first: 2) {

      edges {

        node {
          ... on Ref {
            name
            target {
              ... on Commit {
                # Branch head commit, to determine if branch is stale
                oid  # SHA
                committedDate
                committer { email }
                messageHeadline
                status { state }

                # History example
                history(first: 2, since: "2018-06-01T00:00:01") {
                  edges {
                    node {
                      ... on Commit {
                        committedDate
                        committer {
                          email
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }

      }

      # Paginate the branches
      pageInfo {
        startCursor
        hasNextPage
        endCursor
      }

    }
  }
}
GRAPHQL


# result = GitHubGraphQL::Client.query(BranchQuery)
# pp result



# ref https://developer.github.com/v4/object/pullrequest/


# Limiting the number of PRs to 100.  If we have more than 100 PRs,
# we're in trouble.
PullRequestQuery = client.parse <<-'GRAPHQL'
{
  rateLimit {
    cost
    remaining
    resetAt
  }
  repository(owner: "KlickInc", name: "klick-genome") {
    pullRequests(first: 2, states: [OPEN]) {
      edges {
        node {
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
GRAPHQL

  
result = client.query(PullRequestQuery)
pp result
