require 'yaml'
require 'rbconfig'
require 'fileutils'

require_relative 'lib/github_graphql'

$stdout.sync = true

namespace :gem do

  # May need to manually install a valid cert to get gems.
  # Ref https://github.com/rubygems/rubygems/issues/1745
  desc "Install rubygems cert (only do this if you get ssl failures on install_gems)"
  task :install_cert do
    ruby_bin = RbConfig::CONFIG["bindir"]
    ruby_lib = File.expand_path(File.join(ruby_bin, '..', 'lib', 'ruby'))
    ssl_cert_dirs = Dir.glob("#{ruby_lib}/**/ssl_certs")
    cert = File.join(File.dirname(__FILE__), 'certs', 'RubyGems_GlobalSignRootCA.pem')
    ssl_cert_dirs.each do |d|
      dest = File.join(d, 'GlobalSignRootCA.pem')
      puts "  copying #{cert} to #{dest}"
      FileUtils.copy(cert, dest)
    end
  end

  desc "Install gems"
  task :install do
    lines = File.read(File.join(File.dirname(__FILE__), 'Gemfile')).split("\n")
    gems =
      lines.
        select { |lin| lin =~ /^gem/ }.
        map { |lin| lin.match(/'(.*)'/)[1] }
    # puts gems.inspect
    gems.each { |g| puts "Installing #{g}"; `gem install #{g} --no-ri --no-rdoc` }
  end

end


desc "Dump the GraphQL schema"
task :dump_schema do
  puts "Dumping schema"
  g = GitHubGraphQL.new(GitHubGraphQL.auth_token())
  g.dump_schema(GitHubGraphQL::SCHEMAFILE)
  unauthorized = (File.read(GitHubGraphQL::SCHEMAFILE) =~ /401 Unauthorized/)
  raise "Unauthorized schema dump.  Missing credentials?" if unauthorized
  puts "Dumped schema to #{GitHubGraphQL::SCHEMAFILE}"
end

desc "Clear cache"
task :clear_cache do
  puts "Clearing cache"
  Dir.glob(File.join(File.dirname(__FILE__), 'lib', 'cache', '*.cache')).each do |f|
    puts "  #{f}"
    File.delete(f)
  end
end
