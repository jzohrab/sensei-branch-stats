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

  size_per_day = {
    (dates.min - 1).yyyymmdd() => 0
  }

  (dates.min..Date::today).to_a.each do |d|
    size_per_day[d.yyyymmdd()] = size_per_day[(d-1).yyyymmdd()] + linecount_per_day[d.yyyymmdd()]
  end
  size_per_day
end


def get_growth_over_time(base, branch)
  puts '-' * 20
  puts branch
  all_commits = get_all_commits(base, branch)
  puts all_commits
  build_growth_line(all_commits)
end

branch = 'origin/feature/1418308_move-redirect-bar-to-websrc'


Dir.chdir('../klick-genome') do |d|
  remote_branches = `git branch -r`.split("\n").map { |b| b.strip }
  features = remote_branches.select { |b| b =~ /feature/ }

  data = {}
  features.each do |f|
    data[f] = get_growth_over_time('origin/develop', f)
  end

  pp data
end

