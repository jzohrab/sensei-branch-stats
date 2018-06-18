require 'pp'

$stderr.sync = true
$stdout.sync = true


module BranchStatistics

  class GenerateCharts

    class << self   # All methods are public class (static)

      def generate_all(git, folder)
        large_branch_line_chart(git, File.join(folder, 'large_branch_line_chart.md'))
        # bubble_chart(git, File.join(folder, 'bubble_chart.md'))
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
        chart_days = 14

        largest_20 = data.
                 select { |d| d[:linecount] > 0 }.
                 select { |d| d[:stale] <= changed_since }.
                 sort { |a, b| a[:linecount] <=> b[:linecount] }.
                 reverse[0..19]

        report_days = ((Date::today-chart_days)..Date::today).to_a.map { |d| d.strftime("%Y-%m-%d") }
        largest_20_size_per_day = largest_20.map do |b|
          display_name = b[:branch].gsub('origin/feature/', '')
          growth = report_days.map { |d| b[:growth][d] }
          [display_name, growth].flatten
        end

        table = [ [ 'branches', report_days ].flatten ] +
                largest_20_size_per_day
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


      # WIP, incomplete
      def bubble_chart(git, filename)

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

        output = data.
                 select { |d| d[:linecount] > 0 }.
                 select { |d| d[:stale] <= 20 }.
                 sort { |a, b| a[:linecount] <=> b[:linecount] }.
                 reverse.
                 each_with_index.
                 map do |b, i|
          [ "B#{i + 1}", b[:branch].gsub('origin/feature/', ''), b[:age], b[:filecount], 'feature', b[:linecount] ].join('|')
        end

        # TODO - print to markdown

      end
      

    end  # class << self

  end  # class

end # module
