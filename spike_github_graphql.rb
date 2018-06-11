require "graphql/client"
require "graphql/client/http"
require 'pp'

$token = ARGV[0]
if ($token.nil? || $token == '') then
  raise "Missing argv 0 token"
end
# puts "GOT TOKEN: #{token}"


# See https://developer.github.com/v4/explorer/ for helper when creating queries


module GitHubGraphQL
  # Configure GraphQL endpoint using the basic HTTP network adapter.
  HTTP = GraphQL::Client::HTTP.new("https://api.github.com/graphql") do
    def headers(context)
      # Optionally set any HTTP headers
      {
        "User-Agent" => "My Client",
        "Authorization" => "bearer #{$token}"
      }
    end
  end  

  # Fetch latest schema on init, this will make a network request
  Schema = GraphQL::Client.load_schema(HTTP)

  # However, it's smart to dump this to a JSON file and load from disk
  #
  # Run it from a script or rake task
  #   GraphQL::Client.dump_schema(SWAPI::HTTP, "path/to/schema.json")
  #
  # Schema = GraphQL::Client.load_schema("path/to/schema.json")

  Client = GraphQL::Client.new(schema: Schema, execute: HTTP)
end


BranchQuery = GitHubGraphQL::Client.parse <<-'GRAPHQL'
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
    refs(refPrefix: "refs/heads/", orderBy: {direction: DESC, field: TAG_COMMIT_DATE}, first: 100) {

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
PullRequestQuery = GitHubGraphQL::Client.parse <<-'GRAPHQL'
{
  rateLimit {
    cost
    remaining
    resetAt
  }
  repository(owner: "KlickInc", name: "klick-genome") {
    pullRequests(first: 100, states: [OPEN]) {
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


result = GitHubGraphQL::Client.query(PullRequestQuery)
pp result
