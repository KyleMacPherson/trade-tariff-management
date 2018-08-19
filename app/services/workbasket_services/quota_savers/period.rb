module WorkbasketServices
  module QuotaSavers
    class Period < ::WorkbasketServices::Base

      attr_accessor :saver_class,
                    :attrs_parser,
                    :order_number,
                    :section_ops,
                    :balance_ops
                    :start_point,
                    :end_point

      def initialize(saver_class, section_ops, balance_ops)
        @saver_class = saver_class
        @attrs_parser = saver_class.attrs_parser
        @all_settings = saver_class.settings
                                   .settings
        @order_number = saver_class.order_number_saver
                                   .order_number
        @section_ops = section_ops
        @balance_ops = balance_ops
      end


      def persist!
        quota_definition = QuotaDefinition.new(quota_definition_ops)
        set_system_data(quota_definition)

        if quota_definition.save
          add_measures_for_definition!
          @quota_period_sids << quota_definition.quota_definition_sid
        end

        @start_point = end_point + 1.day
        @end_point = start_point + 1.year
      end

      private

        def description
          all_settings['quota_description']
        end

        def source(key)
          section_ops[key] == "true" ? balance_ops : section_ops
        end

        def critical
          source("criticality_each_period")["critical"] == "true" ? "Y" : "N"
        end

        def critical_threshold
          source("criticality_each_period")["criticality_threshold"].to_i
        end

        def balance
          source("staged")["balance"].to_i
        end

        def duty_expression_list
          source("duties_each_period")["duty_expressions"]
        end

        def measurement_unit_code
          section_ops["measurement_unit_code"]
        end

        def measurement_unit_qualifier_code
          section_ops["measurement_unit_qualifier_code"]
        end

        def defition_ops
          {
            volume: balance,
            initial_volume: balance,
            validity_start_date: start_point,
            validity_end_date: end_point,
            critical_state: critical,
            critical_threshold: critical_threshold,
            description: description,
            quota_order_number_id: order_number.quota_order_number_id,
            quota_order_number_sid: order_number.quota_order_number_sid,
            measurement_unit_code: measurement_unit_code,
            measurement_unit_qualifier_code: measurement_unit_qualifier_code
          }
        end

        def add_measures_for_definition!
          saver_class.candidates.map do |code|
            attrs_parser.instance_variable_set(:@start_date, start_point)
            attrs_parser.instance_variable_set(:@end_date, end_point)

            if period_measure_components.present?
              attrs_parser.instance_variable_set(
                :@measure_components,
                period_measure_components
              )
            end

            saver_class.candidate_validation_errors(code, saver_class.validation_mode)
          end
        end

        def period_measure_components
          measure_components = {}

          duty_expression_list.select do |k, option|
            option["duty_expression_id"].present?
          end.map do |k, duty_expression_ops|
            measure_components[k] = ActiveSupport::HashWithIndifferentAccess.new(
              duty_expression_ops
            )
          end

          measure_components
        end
    end
  end
end
