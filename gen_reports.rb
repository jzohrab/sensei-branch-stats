# Given a folder with results,
# generate some markdown reports in that folder.

require 'yaml'
require "active_support/inflector"
require "active_support/notifications"


# Monkeypatch String for reports.
class String
  def flag
    "<span style=\"color:red\">**#{self}**</span>"
  end
  
  def flag_if(b)
    return self if !b
    return flag()
  end
end



module BranchStatistics

  # Convert status to nice images.
  class StatusImage

    def initialize(status)
      @status = status
      @img = "<svg width='20' height='20'><circle cx='10' cy='10' r='8' stroke='grey' stroke-width='0.5' fill='#{status}' /></svg>"
    end

    def to_s()
      @img
    end

    @@green = StatusImage.new(:green)
    @@red = StatusImage.new(:red)
    @@yellow = StatusImage.new(:yellow)
    @@white = StatusImage.new(:white)

    def self.Green
      @@green
    end
    def self.Yellow
      @@yellow
    end
    def self.Red
      @@red
    end
    def self.White
      @@white
    end

    def self.symbolize(s)
      return s if s.is_a?(StatusImage)

      case s.to_s.upcase
      when 'YES', 'GOOD', 'APPROVED', 'SUCCESS', 'TRUE', 'QA APPROVED'
        StatusImage.Green
      when 'NO', 'BAD', 'CHANGES_REQUESTED', 'FAILURE', 'QA BUG', 'FALSE'
        StatusImage.Red
      when 'PENDING', 'UNKNOWN'
        StatusImage.Yellow
      else
        StatusImage.White
      end
    end

    def self.worst_of(string_array)
      syms = string_array.map { |s| self.symbolize(s) }
      [StatusImage.Red, StatusImage.Yellow, StatusImage.Green].each do |s|
        return s if syms.include?(s)
      end
      StatusImage.White  # Fallback
    end

  end


  class GenerateReports

    class << self   # All methods are public class (static)

      def generate_all(data, folder)
        gen_branches(data, File.join(folder, 'branches.md'))
        gen_pull_requests(data, File.join(folder, 'pull_requests.md'))
        gen_branches_and_pull_requests(data, File.join(folder, 'branches_and_pull_requests.md'))
      end
      
      def gen_branches(data, filename)
        headings = [:branch, :ci, :authors, :last_commit, :change]
        create_row = lambda do |d|
          b = d[:branch]
          c = d[:commits]
          row = {
            ci: StatusImage.symbolize(b[:status]),
            branch: b[:name],
            authors: authors(d),
            last_commit: b[:last_commit].flag_if(b[:last_commit_age] > 20),
            change: "+#{c[:additions]} / -#{c[:deletions]}",

            last_commit_SORT_KEY: b[:last_commit]
          }
          row
        end

        include_branches = [ /feature/, /hotfix/ ]
        rows = data.
               select { |d| include_branches.any? { |r| d[:branch][:name] =~ r } }.
               map { |d| create_row.call(d) }

        File.open(filename, 'w') do |f|
          put_markdown_table(f, headings, rows, :last_commit_SORT_KEY, false)
        end
        puts "Wrote #{filename}"
      end


      def gen_pull_requests(data, filename)
        headings = [:status, :pull_request, :created, :c, :m, :r]
        create_row = lambda do |d|
          pr = d[:pr]
          title = "[#{pr[:number]}: #{pr[:title]}](#{pr[:url]})"
          title = "#{title}<br />#{authors(d, ', ')}"
          revs = pr[:reviews].map { |r| r[:status] }.select { |r| r != 'COMMENTED' }

          row = {
            pull_request: title,
            branch: d[:branch][:name],
            authors: authors(d),
            created: pr[:created].gsub(/^20/, '').flag_if(pr[:age] > 20),
            c: StatusImage.symbolize(d[:branch][:status]),
            m: StatusImage.symbolize(pr[:mergeable]),
            r: StatusImage.worst_of(revs),
            age_SORT_KEY: pr[:age]
          }
          row[:c_m_r] = [:c, :m, :r].map { |sym| row[sym] }.join('')
          row[:status] = StatusImage.worst_of([:c, :m, :r].map { |sym| row[sym] })
          row
        end

        rows =
          data.
          select { |d| d[:pr].keys().size() > 0 }.
          map { |d| create_row.call(d) }

        File.open(filename, 'w') do |f|
          f.puts "**Key**: c = passes CI; m = mergeable (no conflicts); r = reviews"
          f.puts
          put_markdown_table(f, headings, rows, :age_SORT_KEY, true)
        end
        puts "Wrote #{filename}"
      end


      def gen_branches_and_pull_requests(data, filename)

        headings = [:branch, :last_commit, :pull_request, :ci, :r, :m, :qa]
        create_row = lambda do |d|

          b = d[:branch]
          c = d[:commits]
          pr = d[:pr]

          branch_title = "#{b[:name]}<br /><span style='font-size: 10px'>#{authors(d, ', ')}</span>"
          pr_link = pr[:number] ? "[#{pr[:number]}](#{pr[:url]})" : ''
          reviews = pr[:reviews] || [{}]
          rev_statuses = reviews.map { |r| r[:status] }.select { |r| r != 'COMMENTED' }
          qa_statuses = pr[:labels] || []
          qa_statuses = qa_statuses.select { |label| label =~ /QA/ }

          row = {
            branch: branch_title,
            last_commit: b[:last_commit].flag_if(b[:last_commit_age] > 20),
            pull_request: pr_link,
            ci: StatusImage.symbolize(d[:branch][:status]),
            r: StatusImage.worst_of(rev_statuses),
            m: StatusImage.symbolize(pr[:mergeable]),
            qa: StatusImage.worst_of(qa_statuses),
            last_commit_SORT_KEY: b[:last_commit]
          }

          row
        end

        include_branches = [ /feature/, /hotfix/ ]
        rows = data.
               select { |d| include_branches.any? { |r| d[:branch][:name] =~ r } }.
               map { |d| create_row.call(d) }

        File.open(filename, 'w') do |f|
          f.puts "**Key**: ci = passes CI; m = mergeable (no conflicts); r = reviews"
          put_markdown_table(f, headings, rows, :last_commit_SORT_KEY, false)
        end
        puts "Wrote #{filename}"

      end


      #################################

      def put_markdown_table(ostream, headings, rows, order_by = nil, ascending = true)
        print_lin = lambda do |a|
          cleaned_a = a.map { |el| el.to_s.gsub('|', '-') }
          ostream.puts "| #{cleaned_a.join(' | ')} |"
        end
        # ostream.puts "<div style=\"font-size:10px\">"
        # ostream.puts  # Space after div is required for wiki
        print_headings =
          headings.
          map { |h| h.to_s.gsub('_', ' ') }

        print_lin.call(print_headings)
        print_lin.call(headings.map { |h| '---' })

        puts "Have order_by, vals = #{rows.map { |r| r[order_by] }}" if order_by
        rows.sort! { |a, b| a[order_by] <=> b[order_by] } if order_by
        rows.reverse! if (order_by and !ascending)

        rows.each do |row|
          print_lin.call(headings.map { |h| row[h] })
        end
        # ostream.puts "</div>"
      end


      def authors(data, join_with = '<br />')
        data[:commits][:authors].
          map { |a| a.gsub(/@.*/, '') }.
          join(join_with)
      end


    end   # class << self

  end  # class

end  # module


#################################


if __FILE__ == $0 then
  folder = ARGV[0]
  result_path = File.join(folder, 'result.yml')
  raise "Missing result file #{result_path}" if !File.exist?(result_path)
  data = YAML.load_file(result_path)
  BranchStatistics::GenerateReports.generate_all(data, folder)
end
