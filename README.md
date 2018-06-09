# Spike github graphql

```
bundle install
ruby spike.rb <github token (graphql-spike token)>
```

returns

```
#<GraphQL::Client::Response:0x0000000007fa2150
 @data=#< rateLimit=... repository=...>,
 @errors=#<GraphQL::Client::Errors @messages={} @details={}>,
 @extensions=nil,
 @original_hash=
  {"data"=>
    {"rateLimit"=>
      {"cost"=>1, "remaining"=>4990, "resetAt"=>"2018-06-08T22:23:20Z"},
     "repository"=>
      {"refs"=>
        {"edges"=>
          [{"node"=>
             {"name"=>"wip/1346200-remove-new-keyword-warnings",
              "target"=>{"__typename"=>"Commit", "history"=>{"edges"=>[]}}}},
           {"node"=>
             {"name"=>"wip/1219370",
              "target"=>{"__typename"=>"Commit", "history"=>{"edges"=>[]}}}}],
         "pageInfo"=>
          {"startCursor"=>"MQ==",
           "hasNextPage"=>true,
           "endCursor"=>"Mg=="}}}}}>
```

## Notes

* https://developer.github.com/v4/explorer/ - useful for building and testing queries.


# Ruby to get branch stats

See branch_bubble_chart.rb

Sample chart https://docs.google.com/spreadsheets/d/1b1knPnxX9ZXV26wUJdLjRQno1juuYRZdx-rs7MR5EhU/edit#gid=191409366
