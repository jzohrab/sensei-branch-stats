require 'pp'
require 'yaml'

require_relative 'lib/github_branch_query'
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


# Helper during dev.
def write_cache(result, f)
  cachefile = File.join(File.dirname(__FILE__), 'cache', f)
  File.open(cachefile, 'w') do |file|
    file.write result
  end
  $stdout.puts "Wrote #{f}"
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


vars = github_config
result = BranchQuery.new().collect_branches(vars)
write_cache(result.to_yaml, 'response.yml')


git = BranchStatistics::Git.new(local_git_config[:repo_dir], local_git_config)
remote = local_git_config[:remote_name]
git.fetch_and_prune()

$stdout.puts "Analyzing #{result.size} branches in repo #{local_git_config[:repo_dir]}"
n = 0
commit_stats = {}
result.each do |b|
  n += 1
  $stdout.puts "  #{n} of #{result.size}" if (n % 10 == 0)
  c = git.branch_stats("#{remote}/develop", "#{remote}/#{b.name}")
  commit_stats[b.name] = c.slice(:branch, :sha, :authors, :ahead, :linecount, :filecount)
end
write_cache(commit_stats.to_yaml, 'commits.yml')

# Final transform
branch_data = result.map do |branch|
  branch_data = {
      name: branch.name,
      committer: branch.target.committer.email,
      last_commit: get_yyyymmdd(branch.target.committed_date),
      last_commit_age: age(branch.target.committed_date),
      status: branch.target.status ? branch.target.status.state : nil
  }

  pr_data = {}
  if (branch.associated_pull_requests.nodes.size() == 1) then
    pr = branch.associated_pull_requests.nodes[0]
    pr_data = {
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
  
  {
    branch: branch_data,
    pr: pr_data,
    commits: commit_stats[branch.name]
  }
end

write_cache(result.to_yaml, 'result.yml')
