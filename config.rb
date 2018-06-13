# Read the supplied configuration file

require 'yaml'


# Yaml hash keys are strings, convert to symbols:
# https://stackoverflow.com/questions/800122/best-way-to-convert-strings-to-symbols-in-hash
class Object
  def deep_symbolize_keys
    return self.inject({}){|memo,(k,v)| memo[k.to_sym] = v.deep_symbolize_keys; memo} if self.is_a? Hash
    return self.inject([]){|memo,v    | memo           << v.deep_symbolize_keys; memo} if self.is_a? Array
    return self
  end
end


module BranchStatistics

  class Configuration

    def self.read_config(config_file)
      if config_file.nil? then
        raise "Usage: ruby #{$0} <path_to_file>"
      end
      raise "Missing config file #{config_file}" if !File.exist?(config_file)
      full_config = YAML.load_file(config_file)

      full_config = full_config.deep_symbolize_keys

      # Set defaults
      full_config[:github][:resultsize] = 100 if full_config[:github][:resultsize].nil?

      full_config
    end

  end

end
