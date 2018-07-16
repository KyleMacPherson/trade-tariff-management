module Measures
  class ValidationHelper

    attr_accessor :measure,
                  :errors

    def initialize(measure, errors)
      @measure = measure
      @errors = errors

      measure_base_validation!

      self
    end

    private

      def measure_base_validation!
        @base_validator = base_validator.validate(measure)

        if measure.conformance_errors.present?
          measure.conformance_errors.map do |error_code, error_details_list|
            @errors[get_error_area(error_code)] = error_details_list.map do |error_message|
              code = error_code
              code = code.join(', ') if error_code.is_a?(Array)

              message = error_message
              message = message.tr("\n","") if message.include?("\n")

              "#{code}: #{message}"
            end.uniq
          end
        end
      end

      def base_validator
        @base_validator ||= MeasureValidator.new
      end

      def get_error_area(error_code)
        base_validator.detect do |v|
          v.identifiers == error_code
        end.validation_options[:of]
      end
  end
end
