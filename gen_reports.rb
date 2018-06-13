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
  print_lin.call(headings)
  print_lin.call(headings.map { |h| '---' })

  rows.sort! { |a, b| a[order_by] <=> b[order_by] } if order_by
  rows.reverse! if (order_by and !ascending)

  rows.each do |row|
    print_lin.call(headings.map { |h| row[h] })
  end
  ostream.puts "</div>"
end


def gen_branches(data, filename)
  headings = [:name, :last_commit, :last_commit_age, :status, :authors]
  create_row = lambda do |d|
    r = d[:branch].slice(*headings)
    r[:authors] = d[:commits][:authors].join(', ')
    r
  end

  include_branches = [ /feature/, /hotfix/ ]
  rows =
    data.
      select { |d| include_branches.any? { |r| d[:branch][:name] =~ r } }.
      map { |d| create_row.call(d) }

  File.open(filename, 'w') do |f|
    f.puts "# Branches"
    f.puts
    put_markdown_table(f, headings, rows, :last_commit_age, false)
  end
  puts "Wrote #{filename}"
end

#################################

folder = ARGV[0]
result_path = File.join(folder, 'result.yml')
raise "Missing result file #{result_path}" if !File.exist?(result_path)

data = YAML.load_file(result_path)
# puts data.inspect

gen_branches(data, File.join(folder, 'branches.md'))
