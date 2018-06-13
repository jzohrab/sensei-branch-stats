require 'yaml'
# require 'json'
# require 'ostruct'

require_relative 'github_graphql'


# Yaml hash keys are strings, convert to symbols with snake-style naming
# (e.g., hsh['someThingHere'] => hsh[:some_thing_here]
# https://stackoverflow.com/questions/800122/best-way-to-convert-strings-to-symbols-in-hash
class Object
  def snaky_symbol(s)
    mapped = s.chars.map do |c|
      (c.downcase == c) ? c : "_#{c.downcase}"
    end
    ret = mapped.join('').gsub(/^_/, '').to_sym
    ret
  end
  
  def deep_symbolize_snakified_keys
    return self.inject({}){|memo,(k,v)| memo[snaky_symbol(k)] = v.deep_symbolize_snakified_keys; memo} if self.is_a? Hash
    return self.inject([]){|memo,v    | memo           << v.deep_symbolize_snakified_keys; memo} if self.is_a? Array
    return self
  end
end


# Monkeypatching ... could be problematic
class Hash
  def method_missing(m, *args, &blk)
    fetch(m) { fetch(m.to_s) { super } }
  end
end


class GitHubBranchQuery

    # queryfile = File.join(File.dirname(__FILE__), '..', 'queries', 'branches_and_pull_requests.graphql')
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

  def initialize()
    g = GitHubGraphQL.new(GitHubGraphQL.auth_token())
    @client = g.client()
  end


  def collect_branches(vars)
    cachefile = File.join(File.dirname(__FILE__), 'cache', "BranchQuery_#{vars[:owner]}_#{vars[:repo]}.cache")
    
    $stdout.puts "Fetching branches from GitHub GraphQL, in sets of #{vars[:resultsize]} branches"
    result = get_cached_result(cachefile)
    if !result.nil? then
      $stdout.puts "  using cached results"
      return result
    end

    result = collect_branches_iter(BranchQueryDefinition, vars, nil)
    File.open(cachefile, 'w') do |file|
      file.write result.map { |n| n.to_h }.to_yaml
    end

    return result
  end


  def get_cached_result(cachefile)
    return nil if !File.exist?(cachefile)
    age_in_seconds = (Time.now - File.stat(cachefile).mtime).to_i
    return nil if (age_in_seconds > 10 * 60)
    ret = YAML.load_file(cachefile)
    ret.map! { |r| r.deep_symbolize_snakified_keys() }
    ret
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


