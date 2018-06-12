require 'yaml'
require_relative 'lib/github_graphql'


desc "Dump the GraphQL schema"
task :dump_schema do
  puts "Dumping schema"
  g = GitHubGraphQL.new(GitHubGraphQL.auth_token())
  g.dump_schema(GitHubGraphQL::SCHEMAFILE)
  unauthorized = (File.read(GitHubGraphQL::SCHEMAFILE) =~ /401 Unauthorized/)
  raise "Unauthorized schema dump.  Missing credentials?" if unauthorized
  puts "Dumped schema to #{GitHubGraphQL::SCHEMAFILE}"
end
