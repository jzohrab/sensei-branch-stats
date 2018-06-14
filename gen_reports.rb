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
  
  def flag_if!(b)
    return self if !b
    self.replace(flag)
  end
end



module BranchStatistics

  # Convert status to nice images.
  class StatusImage

    def initialize(status)
      @status = status
      @img = "<svg width='20' height='20'><circle cx='10' cy='10' r='8' stroke='black' stroke-width='1' fill='#{status}' /></svg>"
    end

    def to_s()
      @img
    end

    @@green = StatusImage.new(:green)
    @@red = StatusImage.new(:red)
    @@yellow = StatusImage.new(:yellow)

    def self.Green
      @@green
    end
    def self.Yellow
      @@yellow
    end
    def self.Red
      @@red
    end

    def self.symbolize(s)
      case s
      when 'yes', 'good', 'APPROVED', 'SUCCESS', 'true', true
        StatusImage.Green
      when 'no', 'bad', 'CHANGES_REQUESTED', 'FAILURE', 'false', false
        StatusImage.Red
      when 'PENDING', 'UNKNOWN', nil
        StatusImage.Yellow
      else
        s
      end
    end

    def self.worst_of(string_array)
      syms = string_array.map { |s| self.symbolize(s) }
      [StatusImage.Red, StatusImage.Yellow, StatusImage.Green].each do |s|
        return s if syms.include?(s)
      end
      StatusImage.Yellow  # Fallback
    end

  end


  class GenerateReports

    class << self   # All methods are public class (static)

      def generate_all(data, folder)
        gen_branches(data, File.join(folder, 'branches.md'))
        gen_pull_requests(data, File.join(folder, 'pull_requests.md'))
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
            last_commit: b[:last_commit],
            change: "+#{c[:additions]} / -#{c[:deletions]}",

            # Add a sort key, dup it to ensure later mutation doesn't break it.
            last_commit_SORT_KEY: b[:last_commit].dup
          }
          row[:last_commit].flag_if!(b[:last_commit_age] > 20)
          row[:change].flag_if!(c[:additions] + c[:deletions] > 500)
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
            created: pr[:created].gsub(/^20/, ''),
            c: StatusImage.symbolize(d[:branch][:status]),
            m: StatusImage.symbolize(pr[:mergeable]),
            r: StatusImage.worst_of(revs),
            age_SORT_KEY: pr[:age]
          }
          row[:created].flag_if!(pr[:age] > 20)
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
