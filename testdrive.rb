require_relative 'lib/git'
require 'pp'

g = BranchStatistics::Git.new('../klick-genome', { :verbose => true })
# g.run('git fetch')
# puts g.get_output('git branch -r')

pp g.branch_stats('origin/develop', 'origin/feature/WIP-PLAT-213-spike-Jenkins-build')
