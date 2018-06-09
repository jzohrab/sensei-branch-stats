require 'date'

$stderr.sync = true
$stdout.sync = true

today = Date::today


def from_today(s)
  return 0 if s.nil?
  d = Date.strptime(s,"%Y-%m-%d")
  return (Date::today - d).to_i
end


def branch_stats(base_branch, b)
  reverse_commits = `git log #{base_branch}..#{b} --reverse --date=short --pretty=format:%cd`.split("\n")
  ret = {
    :ahead => reverse_commits.size,
    :first_commit_date => reverse_commits[0],
    :age => from_today(reverse_commits[0]),
    :last_commit_date => reverse_commits[-1],
    :stale => from_today(reverse_commits[-1])
  }

  ret.merge! get_diff_numstat_summary(base_branch, b)

  ret
end


def get_diff_numstat_summary(base_branch, b)
  cmd = "git diff #{base_branch}...#{b} --numstat"
  # puts cmd
  # return
  
  # outputs "additions  deletions  filename" (tab-separated)
  raw = `#{cmd}`.split("\n")
  # puts raw.inspect
  data = raw.map do |line|
    add, delete, filename = line.split("\t")
    [add.to_i, delete.to_i, filename]
  end

  additions = data.map { |d| d[0] }.reduce(0, :+)
  deletions = data.map { |d| d[1] }.reduce(0, :+)

  return {
    :branch => b,
    :diff_stats => data,
    :additions => additions,
    :deletions => deletions,
    :linecount => additions + deletions,
    :file_count => data.size()
  }

end

Dir.chdir('../klick-genome') do |d|
  puts "#{d}"
  remote_branches = `git branch -r`.split("\n").map { |b| b.strip }
  features = remote_branches.select { |b| b =~ /feature/ }

  n = 0
  data = features.map do |b|
    n += 1
    $stderr.puts " #{b} (#{n} of #{features.size})"
    branch_stats('origin/develop', b)
  end

  puts "Done\n\n"
  data.select { |d| d[:linecount] > 0 }.select { |d| d[:stale] <= 20 }.each_with_index do |b, i|
    puts [ i + 1, b[:branch].gsub('origin/feature/', ''), i + 1, b[:age], b[:file_count], 'feature', b[:linecount] ].join('|')
  end

end


