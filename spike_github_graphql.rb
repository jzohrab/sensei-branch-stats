require "graphql/client"
require "graphql/client/http"
require 'pp'
require 'yaml'

require_relative 'lib/github_graphql'
require_relative 'lib/git'

############################
# Config

config_file = ARGV[0]
if config_file.nil? then
  puts "Usage: ruby #{$0} <path_to_file>"
  exit(0)
end
raise "Missing config file #{config_file}" if !File.exist?(config_file)
full_config = YAML.load_file(config_file)

# Yaml hash keys are strings, convert to symbols:
# https://stackoverflow.com/questions/800122/best-way-to-convert-strings-to-symbols-in-hash
class Object
  def deep_symbolize_keys
    return self.inject({}){|memo,(k,v)| memo[k.to_sym] = v.deep_symbolize_keys; memo} if self.is_a? Hash
    return self.inject([]){|memo,v    | memo           << v.deep_symbolize_keys; memo} if self.is_a? Array
    return self
  end
end
full_config = full_config.deep_symbolize_keys


github_config = full_config[:github]
local_git_config = full_config[:local_repo]

# Set defaults
github_config[:resultsize] = 100 if github_config[:resultsize].nil?

############################

# Iterative recursion, collect results in all_branches array.
def collect_branches(client, query, vars, end_cursor, all_branches = [])

  # Shortcut during dev
  if vars[:stopafter] then
    return all_branches if (all_branches.size() > vars[:stopafter].to_i)
  end
  
  $stdout.puts "  fetching (currently have #{all_branches.size} branches)"

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
  File.open(write_to, 'w') do |file|
    file.write result.to_yaml
  end
end



def age(s)
  d = Date.strptime(get_yyyymmdd(s), "%Y-%m-%d")
  age = (Date::today - d).to_i
end

def get_yyyymmdd(s)
  s.match(/(\d{4}-\d{2}-\d{2})/)[1]
end

# Review dates are stored as "2018-06-12T13:43:35Z",
# need date and time to determine the last review.
def get_yyyymmdd_hhnnss(s)
  return s.gsub('T', ' ').gsub('Z', '')
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
      date: get_yyyymmdd_hhnnss(r.updated_at),
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



g = GitHubGraphQL.new(GitHubGraphQL.auth_token())
client = g.client()
queryfile = File.join(File.dirname(__FILE__), 'queries', 'branches_and_pull_requests.graphql')
BranchQuery = client.parse(File.read(queryfile))

vars = github_config
$stdout.puts "Fetching branches from GitHub GraphQL, in sets of #{vars[:resultsize]} branches"
result = collect_branches(client, BranchQuery, vars, nil)

# outfile = File.join(File.dirname(__FILE__), 'cache', 'response.yml')
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
    number: pr.number,
    title: pr.title,
    url: pr.url,
    created: pr.created_at,
    age: age(pr.created_at),
    mergeable: pr.mergeable == 'MERGEABLE',
    reviews: get_pr_review_data(pr)
  }
end

# puts branch_data
# puts pr_data


git = BranchStatistics::Git.new(local_git_config[:repo_dir], local_git_config)
remote = local_git_config[:remote_name]
if local_git_config[:fetch] then
  $stdout.puts "Fetching"
  git.run("git fetch #{remote}")
end
if local_git_config[:prune] then
  $stdout.puts "Pruning"
  git.run("git remote prune #{remote}")
end

$stdout.puts "Analyzing #{branch_data.size} branches in repo #{local_git_config[:repo_dir]}"
n = 0
commit_stats = branch_data.map do |b|
  n += 1
  $stdout.puts "  #{n} of #{branch_data.size}" if (n % 10 == 0)
  git.branch_stats("#{remote}/develop", "#{remote}/#{b[:name]}")
end.map do |c|
  {
    branch: c[:branch],
    authors: c[:authors],
    ahead: c[:ahead],
    linecount: c[:linecount],
    filecount: c[:filecount]
  }
end


result = branch_data.map do |b|
  {
    branch: b,
    pr: pr_data.select { |pr| pr[:branch] == b[:name] }[0],
    commits: commit_stats.select { |c| c[:branch] == "#{remote}/#{b[:name]}" }[0]
  }
end

# puts result

outfile = File.join(File.dirname(__FILE__), 'cache', 'result.yml')
File.open(outfile, 'w') do |file|
  file.write result.to_yaml
end
puts "Wrote data to #{outfile}"
