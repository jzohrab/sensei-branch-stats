# Certs

## RubyGems_GlobalSignRootCA.pem

Ruby gems needs a valid public cert, it can fail on windows.
Ref https://github.com/rubygems/rubygems/issues/1745
Source: https://raw.githubusercontent.com/rubygems/rubygems/master/lib/rubyge

Copy this file to your ruby dir, e.g., to
`C:\\Ruby23\\lib\\ruby\\2.3.0\\rubygems\\ssl_certs\\GlobalSignRootCA.pem`