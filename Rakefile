require 'yaml'
require_relative 'lib/github_graphql'

desc "push tokens into ENV"
task :configure_ENV do
  key = GitHubGraphQL::TOKEN
  github_creds_file = File.join(File.dirname(__FILE__), 'github_creds.yml')
  if (ENV[key].nil? && File.exist?(github_creds_file)) then
    puts "Setting #{key}"
    hsh = YAML.load_file(github_creds_file)
    token = hsh[key]
    ENV[key] = token
  end
end

desc "Dump the GraphQL schema"
task :dump_schema => [:configure_ENV] do
  puts "Dumping schema"
  g = GitHubGraphQL.new()
  g.dump_schema(GitHubGraphQL::SCHEMAFILE)
  puts "Dumped schema to #{GitHubGraphQL::SCHEMAFILE}"
end
