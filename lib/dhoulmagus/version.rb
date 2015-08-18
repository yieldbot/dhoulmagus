require 'json'

# encoding: utf-8
module Dhoulmagus
  # This defines the version of the gem
  module Version
    MAJOR = 0
    MINOR = 0
    PATCH = 23

    STRING = [MAJOR, MINOR, PATCH].compact.join('.')

    NAME   = 'Dhoulmagus'
    BANNER = "#{NAME} v%s"

    module_function

    def version
      format(BANNER, STRING)
    end

    def json_version
      {
        'version' => STRING
      }.to_json
    end
  end
end
