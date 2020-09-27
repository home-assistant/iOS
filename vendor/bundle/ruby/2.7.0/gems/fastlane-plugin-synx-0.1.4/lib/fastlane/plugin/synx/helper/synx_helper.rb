module Fastlane
  module Helper
    class SynxHelper
      # class methods that you define here become available in your action
      # as `Helper::SynxHelper.your_method`
      #
      def self.show_message
        UI.message("Hello from the synx plugin helper!")
      end
    end
  end
end
