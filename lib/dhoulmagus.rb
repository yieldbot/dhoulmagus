require 'dhoulmagus/version'

# Load the defaults
#
module Dhoulmagus
  class << self
      attr_writer :ui
        end

  class << self
      attr_reader :ui
        end
                end
