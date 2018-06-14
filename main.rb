require 'yaml'
require 'fileutils'

require_relative 'lib/github_branch_query'
require_relative 'lib/git'
require_relative 'config'
require_relative 'transform'
require_relative 'gen_reports'
require_relative 'gen_charts'


# Config

config_file = ARGV[0]
full_config = BranchStatistics::Configuration.read_config(config_file)

github_config = full_config[:github]
local_git_config = full_config[:local_repo]

# Fetch

result = GitHubBranchQuery.new().collect_branches(github_config)

git = BranchStatistics::Git.new(local_git_config[:repo_dir], local_git_config)
remote = local_git_config[:remote_name]
git.fetch_and_prune()
remote_branches = result.map { |b| "#{remote}/#{b.name}" }
commit_stats = git.all_branch_basic_stats("#{remote}/develop", remote_branches)

# all_branch_basic_stats is a hash, and the key includes the remote
# name.  Remove it so that the stats can be matched with the result
# from GitHub, which doesn't have the remote name in branch.name.
commit_stats.keys().each do |k|
  commit_stats[k.gsub("#{remote}/", '')] = commit_stats[k]
end


# Transform

branch_data = BranchStatistics::Transform.transform(result, commit_stats)

# Output

[
  [result.to_yaml, 'github_api_response.yml'],
  [commit_stats.to_yaml, 'commits.yml'],
  [branch_data.map { |b| b.to_h }.to_yaml, 'result.yml']
].each do |result, filename|

  f = File.join('results', github_config[:repo], filename)
  fullpath = File.join(File.dirname(__FILE__), f)
  FileUtils.mkdir_p File.dirname(fullpath)
  File.open(fullpath, 'w') { |file| file.write result }
  $stdout.puts "Wrote #{f}"
end


# Create reports and charts

folder = File.join('results', github_config[:repo])
BranchStatistics::GenerateReports.generate_all(branch_data, folder)
BranchStatistics::GenerateCharts.generate_all(git, folder)
