# Wrapper around Git for local branch inspection.

require 'open3'
require 'date'


$stderr.sync = true
$stdout.sync = true


module BranchStatistics

  class Git

    def initialize(repo_directory, options = {})
      @repo_dir = repo_directory
      @options = options
    end

    def log(s)
      puts s if @options[:verbose]
    end

    def run(cmd)
      get_output(cmd)
    end


    # Get output as an array of strings.
    def get_output(cmd)
      log "Running #{cmd}"
      # git commands output fatal errors to stderr,
      # so capture that.
      # (ref http://blog.honeybadger.io/capturing-stdout-stderr-from-shell-commands-via-ruby/)
      stdout, stderr, status = nil, nil, nil
      Dir.chdir(@repo_dir) do |d|
        stdout, stderr, status = Open3.capture3(cmd)
      end

      if (stderr.strip != "" and stderr =~ /fatal/m) then
        msg = <<HERE
stderr fatal error:
#{stderr}
Raised during git command:
#{cmd}
HERE
        raise msg
      end

      # Some git commit subject lines contained control characters ("^M")
      # which broke parsing.  I tried using the methods given in
      # https://www.ruby-forum.com/topic/172061 to remove those bad chars,
      # but it didn't work.  Below is adapted from
      # https://rosettacode.org/wiki/Strip_control_codes_and_extended_characters_from_a_string#Ruby
      clean_stdout = stdout.chars.each_with_object("") do |char, str|
        displayable = (char.ascii_only? and char.ord.between?(32,126))
        str << char if (displayable || char == "\n" || char == "\t")
      end
      
      return clean_stdout.
              split("\n").
              map { |s| s.strip }.
              select { |s| s != '' }
    end

    def fetch_and_prune()
      remote = @options[:remote_name]
      if @options[:fetch] then
        $stdout.puts "Fetching"
        self.run("git fetch #{remote}")
      end
      if @options[:prune] then
        $stdout.puts "Pruning"
        self.run("git remote prune #{remote}")
      end
    end


    def get_all_commits(base, branch)
      # Getting base commit data, including numstat.  Parsing
      # multiline strings into groups is annoying, so being lazy and
      # using a delimiter to indicate the start of each commit, and
      # splitting on that.
      delimiter = '__COMMIT_START__'
      cmd = "git log #{base}..#{branch} --no-merges --date=short --format=\"#{delimiter}%cd|%H|%ae\" --numstat"
      raw = get_output(cmd).join("\n")
      raw_commits = raw.split(delimiter).select { |c| c != '' }

      log("Command: #{cmd}")
      log("Split raw commits:")
      log(raw_commits.inspect)

      commits = raw_commits.map { |r| parse_commit_data(r) }
    end
    
    
    def parse_commit_data(s)
      data = s.split("\n")
      stats = parse_diff_stats(data[2..-1])
      commit_date, sha, author_email = data[0].split('|')
      {
        :author => author_email,
        :date => commit_date,
        :sha => sha
      }.merge(stats)
    end


    # Diff stats are as follows:
    # additions <tab> subtractions <tab> filename
    def parse_diff_stats(diff_rows)
      if diff_rows.nil? || diff_rows.size() == 0 then
        return {
          :additions => 0,
          :deletions => 0,
          :linecount => 0,
          :filecount => 0,
          :changes => 0
        }
      end

      file_changes = diff_rows.map do |line|
        add, delete, filename = line.split("\t")
        [add.to_i, delete.to_i, filename]
      end
      additions = file_changes.map { |d| d[0] }.reduce(0, :+)
      deletions = file_changes.map { |d| d[1] }.reduce(0, :+)
      {
        :additions => additions,
        :deletions => deletions,
        :linecount => additions + deletions,
        :filecount => file_changes.size(),
        :changes => file_changes
      }
    end

    
    def yyyymmdd(d)
      return d.strftime("%Y-%m-%d")
    end
    
    
    def build_growth_hash(commits)
      return {} if commits.size() == 0
      linecount_per_day = Hash.new { |h, k| h[k] = 0 }
      commits.each { |c| linecount_per_day[c[:date]] += c[:linecount] }
      dates = commits.
              map { |c| c[:date] }.uniq.
              map { |s| Date.strptime(s, "%Y-%m-%d") }
    
      size_per_day = Hash.new { |h, k| h[k] = 0 }
      (dates.min..Date::today).to_a.each do |d|
        ds = yyyymmdd(d)
        size_per_day[ds] = size_per_day[yyyymmdd(d - 1)] + linecount_per_day[ds]
      end
      size_per_day
    end
    
    
    def from_today(c)
      return 0 if c.nil? || c[:date].nil?
      d = Date.strptime(c[:date], "%Y-%m-%d")
      return (Date::today - d).to_i
    end


    def branch_stats(base_branch, b)
      commits = get_all_commits(base_branch, b)
      have_commits = commits.size() > 0

      net_stats = parse_diff_stats(get_output("git diff #{base_branch}...#{b} --numstat"))

      ret = {
        :branch => b,
        :sha => have_commits ? commits[0][:sha] : nil,
        :authors => commits.map { |c| c[:author] }.sort.uniq,
        :ahead => commits.size,
        :first_commit_date => have_commits ? commits[-1][:date] : nil,
        :age => have_commits ? from_today(commits[-1]) : 0,
        :last_commit_date => have_commits ? commits[0][:date] : nil,
        :stale => have_commits ? from_today(commits[0]) : 0,
        :additions => net_stats[:additions],
        :deletions => net_stats[:deletions],
        :linecount => net_stats[:linecount],
        :filecount => net_stats[:filecount],
        :commits => commits,
        :growth => build_growth_hash(commits)
      }

      ret
    end
    
    
  end  # Git

end
