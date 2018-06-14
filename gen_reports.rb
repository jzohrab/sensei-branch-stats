# Given a folder with results,
# generate some markdown reports in that folder.

require 'yaml'
require "active_support/inflector"
require "active_support/notifications"


#################################

def put_markdown_table(ostream, headings, rows, order_by = nil, ascending = true)
  print_lin = lambda { |a| ostream.puts "| #{a.join(' | ')} |" }
  ostream.puts "<div style=\"font-size:10px\">"
  ostream.puts  # Space after div is required for wiki
  print_lin.call(headings.map { |h| h.to_s.gsub('_', ' ') })
  print_lin.call(headings.map { |h| '---' })

  rows.sort! { |a, b| a[order_by] <=> b[order_by] } if order_by
  rows.reverse! if (order_by and !ascending)

  rows.each do |row|
    print_lin.call(headings.map { |h| row[h] })
  end
  ostream.puts "</div>"
end


class String
  def flag
    "<span style=\"color:red\">**#{self}**</span>"
  end
  
  def flag_if!(b)
    return self if !b
    self.replace(flag)
  end
end


def symbolize(s)
  # Hack!  I loaded the images into the wiki and noted their IDs.
  img = lambda do |name, f|
    "![#{name}](https://files.wiki.senseilabs.com/#{f})"
  end
  green = img.call('green', '85zxpAMOCaW/aba10f31-2cee-499d-ac31-e3fdd4188c04')
  red = img.call('red', '85zxpAMOCaW/5300c533-ef76-45c6-a601-787f7da8bfac')
  yellow = img.call('yellow', '85zxpAMOCaW/d1c03456-eaf2-47ae-95b6-0f5a080d69da')

  case s
  when 'yes', 'good', 'APPROVED', 'SUCCESS', 'true', true
    green
  when 'no', 'bad', 'CHANGES_REQUESTED', 'FAILURE', 'false', false
    red
  when 'PENDING', nil
    yellow
  else
    s
  end
end


def gen_branches(data, filename)
  headings = [:branch, :authors, :last_commit, :change]
  create_row = lambda do |d|
    b = d[:branch]
    c = d[:commits]
    row = {
      branch: "#{symbolize(b[:status])} #{b[:name]}",
      authors: d[:commits][:authors].join('<br />'),
      last_commit: b[:last_commit],
      change: "+#{c[:additions]} / -#{c[:deletions]}"
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
    f.puts "# Branches"
    f.puts
    put_markdown_table(f, headings, rows, :last_commit, true)
  end
  puts "Wrote #{filename}"
end


def gen_pull_requests(data, filename)
###  headings = [:pull_request, :branch, :authors, :created, :age, :status, :mergeable, :reviews]
###  create_row = lambda do |d|
###    pr = d[:pr]
###    r = pr.slice(*headings)
###    r[:pull_request] = "[#{pr[:number]}: #{pr[:title]}](#{pr[:url]})"
###    r[:authors] = d[:commits][:authors].join('<br />')
###    r[:status] = symbolize(d[:branch][:status])
###    r[:reviews] =
###      d[:pr][:reviews].
###      map { |r| r[:status] }.
###      select { |r| r != 'COMMENTED' }.
###      map { |r| symbolize(r) }.
###      join('')
###    r
###  end
###
###  rows =
###    data.
###    select { |d| d[:pr].keys().size() > 0 }.
###    map { |d| create_row.call(d) }
###
###  File.open(filename, 'w') do |f|
###    f.puts "# Pull Requests"
###    f.puts
###    put_markdown_table(f, headings, rows, :age, false)
###  end
###  puts "Wrote #{filename}"
###
end

#################################

folder = ARGV[0]
result_path = File.join(folder, 'result.yml')
raise "Missing result file #{result_path}" if !File.exist?(result_path)

data = YAML.load_file(result_path)
# puts data.inspect

gen_branches(data, File.join(folder, 'branches.md'))
gen_pull_requests(data, File.join(folder, 'pull_requests.md'))
