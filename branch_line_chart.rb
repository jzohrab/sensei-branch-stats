require_relative 'lib/git'

$stderr.sync = true
$stdout.sync = true


g = BranchStatistics::Git.new('../klick-genome')


remote_branches = g.get_output('git branch -r').map { |b| b.strip }
features =
  remote_branches.
  select { |b| b =~ /feature/ }

n = 0
data = features.map do |b|
  n += 1
  $stderr.puts " #{b} (#{n} of #{features.size})"
  g.branch_stats('origin/develop', b)
end

data = data.
       select { |d| d[:linecount] > 0 }.
       select { |d| d[:stale] <= 60 }.
       sort { |a, b| a[:linecount] <=> b[:linecount] }.
       reverse

data = data[0..19]  # Largest 20 branches


all_dates = data.map { |f| f[:growth].keys }.flatten.sort.uniq
last_20_days = all_dates[-20..-1]
  
fd = data.map do |f|
  growth = last_20_days.map { |d| f[:growth][d] }
  [ f[:branch].gsub('origin/feature/', ''), growth].flatten
end

table = [ [ 'branches', last_20_days ].flatten ] +
        fd

puts table.transpose.map { |row| row.join(',') }


