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

# puts data[0].inspect

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

