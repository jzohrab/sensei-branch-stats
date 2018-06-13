require_relative 'lib/git'
require_relative 'config'

$stderr.sync = true
$stdout.sync = true

config_file = ARGV[0]
full_config = BranchStatistics::Configuration.read_config(config_file)

github_config = full_config[:github]
local_git_config = full_config[:local_repo]

git = BranchStatistics::Git.new(local_git_config[:repo_dir], local_git_config)
remote = local_git_config[:remote_name]
git.fetch_and_prune()

remote_branches = git.get_output('git branch -r').map { |b| b.strip }
features =
  remote_branches.
  select { |b| b =~ /feature/ }

n = 0
data = features.map do |b|
  n += 1
  $stderr.puts " #{n} (#{n} of #{features.size})"
  git.branch_stats('origin/develop', b)
end

puts "Done\n\n"

output = data.
         select { |d| d[:linecount] > 0 }.
         select { |d| d[:stale] <= 20 }.
         sort { |a, b| a[:linecount] <=> b[:linecount] }.
         reverse.
         each_with_index.
         map do |b, i|
  [ "B#{i + 1}", b[:branch].gsub('origin/feature/', ''), b[:age], b[:filecount], 'feature', b[:linecount] ].join('|')
end

puts output
