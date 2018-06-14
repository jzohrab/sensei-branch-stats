# Reads credentials from the environment, or from a creds.yml file

require 'yaml'

module BranchStatistics

  class Credentials

    CREDSFILE = File.join(File.dirname(__FILE__), '..', 'creds.yml')

    GITHUB_GRAPHQL_API_TOKEN_KEY = 'GITHUB_GRAPHQL_API_TOKEN'
    SENSEI_WIKI_API_TOKEN_KEY = 'SENSEI_WIKI_API_TOKEN'

    class << self

      def from_creds_file(name)
        return nil if !File.exist?(CREDSFILE)
        hsh = YAML.load_file(CREDSFILE)
        hsh[name]
      end

      def get(name)
        ret = from_creds_file(name) || ENV[name]
        raise "Missing #{name} in env and creds file" if ret.nil?
        ret
      end

      def GITHUB_GRAPHQL_API_TOKEN()
        get(GITHUB_GRAPHQL_API_TOKEN_KEY)
      end

      def SENSEI_WIKI_API_TOKEN()
        get(SENSEI_WIKI_API_TOKEN_KEY)
      end

    end  # class << self

  end # class
  
end # module
