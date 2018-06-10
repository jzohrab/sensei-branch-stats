require 'date'
require 'pp'

$stderr.sync = true
$stdout.sync = true



def get_all_commits(base, branch)

  cmd = "git log #{base}..#{branch} --no-merges --date=short --format='COMMIT_START: %cd|%h' --numstat"
  raw = `#{cmd}`
  raw_commits = raw.split('COMMIT_START: ').select { |c| c != '' }

  commits = raw_commits.map { |r| parse_commit_data(r) }

  commits
end


def parse_commit_data(s)
  data = s.split("\n")

  commit_date, sha = data[0].split('|')
  
  raw_file_changes = data[2..-1]
  file_changes = raw_file_changes.map do |line|
    add, delete, filename = line.split("\t")
    [add.to_i, delete.to_i, filename]
  end
  additions = file_changes.map { |d| d[0] }.reduce(0, :+)
  deletions = file_changes.map { |d| d[1] }.reduce(0, :+)
  
  {
    :date => commit_date,
    :sha => sha,
    :additions => additions,
    :deletions => deletions,
    :linecount => additions + deletions,
  }

end


class Date
  def yyyymmdd()
    return self.strftime("%Y-%m-%d")
  end
end


def build_growth_line(commits)
  return {} if commits.size() == 0

  linecount_per_day = Hash.new { |h, k| h[k] = 0 }
  commits.each { |c| linecount_per_day[c[:date]] += c[:linecount] }
  dates = commits.
          map { |c| c[:date] }.uniq.
          map { |s| Date.strptime(s, "%Y-%m-%d") }

  size_per_day = Hash.new { |h, k| h[k] = 0 }

  (dates.min..Date::today).to_a.each do |d|
    size_per_day[d.yyyymmdd()] = size_per_day[(d-1).yyyymmdd()] + linecount_per_day[d.yyyymmdd()]
  end
  size_per_day
end


def get_growth_over_time(base, branch)
  # puts '-' * 20
  # puts branch
  all_commits = get_all_commits(base, branch)
  # puts all_commits
  build_growth_line(all_commits)
end



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
    :stale => from_today(reverse_commits[-1]),
    :growth => get_growth_over_time(base_branch, b)
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
  remote_branches = `git branch -r`.split("\n").map { |b| b.strip }
  features =
    remote_branches.
    select { |b| b =~ /feature/ }
    
  n = 0
  data = features.map do |b|
    n += 1
    $stderr.puts " #{b} (#{n} of #{features.size})"
    branch_stats('origin/develop', b)
  end

  data = data.
         select { |d| d[:linecount] > 0 }.
         select { |d| d[:stale] <= 20 }.
         sort { |a, b| a[:linecount] <=> b[:linecount] }.
         reverse

  all_dates = data.map { |f| f[:growth].keys }.flatten.sort.uniq
  # pp all_dates
  last_20_days = all_dates[-20..-1]
  
  fd = data.map do |f|
    growth = last_20_days.map { |d| f[:growth][d] }
    [f[:branch].gsub('origin/feature/', ''), growth].flatten
  end
  # puts fd.inspect
  fd = fd.sort { |a, b| a[-1] <=> b[-1] }.reverse

  # Include the first 10 branches (largest)
  table = [
    [ 'branches', last_20_days ].flatten
  ] + fd[0..10]
  # pp table.transpose

  puts table.transpose.map { |row| row.join(',') }

end

