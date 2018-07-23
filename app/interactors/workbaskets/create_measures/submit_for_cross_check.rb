module Workbaskets
  module CreateMeasures
    class SubmitForCrossCheck

      attr_accessor :workbasket

      def initialize(workbasket)
        @workbasket = workbasket
      end

      def run!
        workbasket.move_status_to!(:submitted_for_cross_check)
        update_collection!
      end

      private

        def update_collection!
          workbasket.settings
                    .collection
                    .map do |item|

            item.move_status_to!(:submitted_for_cross_check)
          end
        end
    end
  end
end