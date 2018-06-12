require "graphql/client"
require "graphql/client/http"
require 'pp'

require_relative 'lib/github_graphql'
require_relative 'lib/git'


# Iterative recursion, collect results in all_branches array.
def collect_branches(client, query, vars, end_cursor, all_branches = [])

  # Shortcut during dev
  if vars[:stopafter] then
    return all_branches if (all_branches.size() > vars[:stopafter].to_i)
  end
  
  $stderr.puts "Fetching #{vars[:resultsize]} branches from GitHub GraphQL ..."

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


# Helper during dev.
def write_raw_results_yaml(result, write_to)
  results_hashed = result.map { |n| n.to_h }
  File.open(write_to, 'w') do |file|
    file.write results_hashed.to_yaml
  end
end



def age(s)
  d = Date.strptime(get_yyyymmdd(s), "%Y-%m-%d")
  age = (Date::today - d).to_i
end

def get_yyyymmdd(s)
  s.match(/(\d{4}-\d{2}-\d{2})/)[1]
end

def get_pending_reviews(requests)
  # puts "REQ: #{requests}"
  requests.map { |r| r.requested_reviewer }.map do |r|
    {
      status: 'PENDING',
      reviewer: r.name,
      date: nil,
      age: nil
    }
  end
end

# GitHub can return multiple reviews for the same person in some cases -
# e.g., a person first declines a PR, and then later approves it.
# For each user, get the latest one only.
def get_reviews(reviews)
  all_revs = reviews.map do |r|
    {
      status: r.state,
      reviewer: r.author.login,
      date: get_yyyymmdd(r.updated_at),
      age: age(r.updated_at)
    }
  end
  revs_by_person = all_revs.group_by { |r| r[:reviewer] }.values
  latest_revs = revs_by_person.map do |persons_reviews|
    persons_reviews.sort { |a, b| a[:date] <=> b[:date] }[-1]
  end

  # if (latest_revs.size() != all_revs.size) then
  #  puts '------- CONDENSING to latest -------'
  #  puts "ALL:\n#{all_revs}"
  #  puts "LATEST:\n#{latest_revs}"
  # end

  latest_revs
end

def get_pr_review_data(pr)
  reviews =
    get_pending_reviews(pr.review_requests.nodes) +
    get_reviews(pr.reviews.nodes)
  reviews
end


####################


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

# outfile = File.join(File.dirname(__FILE__), 'github_graphql_responses', 'response.yml')
# write_raw_results_yaml(result, outfile)


branch_data = result.map do |branch|
  {
    name: branch.name,
    committer: branch.target.committer.email,
    last_commit: get_yyyymmdd(branch.target.committed_date),
    last_commit_age: age(branch.target.committed_date),
    status: branch.target.status ? branch.target.status.state : nil
  }
end

pr_data = result.
          map { |b| b.associated_pull_requests.nodes }.
          select { |prs| prs.size() == 1 }.
          map { |prs| prs[0] }.
          map do |pr|
  {
    branch: pr.head_ref_name,
    pr_number: pr.number,
    title: pr.title,
    url: pr.url,
    pr_created: pr.created_at,
    pr_age: age(pr.created_at),
    mergeable: pr.mergeable == 'MERGEABLE',
    pr_reviews: get_pr_review_data(pr)
  }
end

# puts branch_data
# puts pr_data


g = BranchStatistics::Git.new('../klick-genome')
n = 0
commit_stats = branch_data.map do |b|
  n += 1
  $stderr.puts "Analyzing branch #{n} of #{branch_data.size}" if (n % 10 == 0)
  g.branch_stats('origin/develop', "origin/#{b[:name]}")
end.map do |b|
  {
    authors: b[:authors],
    ahead: b[:ahead],
    linecount: b[:linecount],
    filecount: b[:filecount]
  }
end


result = branch_data.map do |b|
  pr = pr_data.select { |pr| pr[:branch] == b[:name] }[0]
  c = commit_stats.select { |c| c[:branch] == "origin/#{b[:name]}" }[0]
  b.merge(pr || {}).merge(c || {})
end

puts result
