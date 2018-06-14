require 'pp'

$stderr.sync = true
$stdout.sync = true


module BranchStatistics

  class GenerateCharts

    class << self   # All methods are public class (static)

      def generate_all(git, folder)
        large_branch_line_chart(git, File.join(folder, 'large_branch_line_chart.md'))
      end

      def large_branch_line_chart(git, filename)

        remote_branches = git.get_output('git branch -r').map { |b| b.strip }
        features =
          remote_branches.
            select { |b| b =~ /feature/ }

        n = 0
        $stdout.puts "Analyzing #{features.size} branches"
        data = features.map do |b|
          n += 1
          $stdout.puts " #{n} of #{features.size}" if (n%10 == 0)
          git.branch_stats('origin/develop', b)
        end

        changed_since = 60

        data = data.
                 select { |d| d[:linecount] > 0 }.
                 select { |d| d[:stale] <= changed_since }.
                 sort { |a, b| a[:linecount] <=> b[:linecount] }.
                 reverse

        data = data[0..19]  # Largest 20 branches


        all_dates = data.map { |f| f[:growth].keys }.flatten.sort.uniq
        # last_20_days = all_dates[-20..-1]
        last_20_days = ((Date::today-20)..Date::today).to_a.map { |d| d.strftime("%Y-%m-%d") }
        pp last_20_days
        pp data
        puts '-' * 20
        fd = data.map do |f|
          pp f
          growth = last_20_days.map { |d| f[:growth][d] }
          [ f[:branch].gsub('origin/feature/', ''), growth].flatten
        end

        table = [ [ 'branches', last_20_days ].flatten ] +
                fd

        chart_data = table.transpose.map { |row| row.join(',') }

        content = <<ENDCHART
```chart

#{chart_data.join("\n")}

type: line
title: Largest feature branches (changed in last #{changed_since} days)
x.title: Date
y.title: Line changes
width:700
height:500
```
ENDCHART

        File.open(filename, 'w') do |f|
          f.puts content
        end
        puts "Wrote #{filename}"

      end

    end  # class << self

  end  # class

end # module
