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