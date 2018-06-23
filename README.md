# Branch Statistics


## Environment setup

```
bundle install
```

or install the gems in the gemfile:

```
rake install_gems
```

### Troubleshooting gem install

You may have to manually update your Gem SSL cert.
See chris-morgan's comment in
https://github.com/rubygems/rubygems/issues/1745)


## Config

Copy config.yml.example to another file (any filename is fine), and edit it for your GitHub and local repo.

Copy creds.yml.example to creds.yml, and edit it with your tokens.  Optionally, set the keys in this file in your environment.


## Running

```
ruby main.rb config.yml.example
```


## Notes

* https://developer.github.com/v4/explorer/ - useful for building and testing queries.
* This writer doesn't fetch the git repo, as that could cause a problem with very large repos.
  The git repo is assumed to be in a good state prior to calling this, either set up
  manually or as part of an automated job.
