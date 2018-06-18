# Branch Statistics


## Environment setup

```
bundle install
```

or manually install the gems in the gemfile:

```
gem install graphql-client
# ... etc
```

## Config

Copy config.yml.example to another file (any filename is fine), and edit it for your GitHub and local repo.

Copy creds.yml.example to creds.yml, and edit it with your tokens.  Optionally, set the keys in this file in your environment.


## Running

```
ruby main.rb config.yml.example
```


## Notes

* https://developer.github.com/v4/explorer/ - useful for building and testing queries.


# Ruby to get branch stats

See branch_bubble_chart.rb

Sample chart https://docs.google.com/spreadsheets/d/1b1knPnxX9ZXV26wUJdLjRQno1juuYRZdx-rs7MR5EhU/edit#gid=191409366
