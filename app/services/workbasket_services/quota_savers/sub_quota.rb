module WorkbasketServices
  module QuotaSavers
    class SubQuota

      attr_accessor :settings_saver,
                    :attrs_parser,
                    :ops,
                    :base_params,
                    :parent_quota,
                    :order_numbers

      def initialize(settings_saver, base_params, parent_quota)
        @settings_saver = settings_saver
        @attrs_parser = settings_saver.attrs_parser
        @ops = base_params['sub_quotas'] || []
        @base_params = base_params
        @parent_quota = parent_quota
        @order_numbers = []
      end

      def persist!
        @order_numbers = ops.map do |index, item|
          params = base_params
          base_params['quota_ordernumber'] = item['order_number']
          saver = build_order_number!(params)
          saver.valid?
          build_quota_association!(saver.order_number, item['coefficient'].to_f)
          saver.order_number
        end
      end

      def add_period!(source_definition, section_ops, balance_ops)
        @section_ops = section_ops
        @balance_ops = balance_ops
        order_numbers.each_with_index do |order_number, index|
          definition = QuotaDefinition.new(
              volume: source_definition.volume,
              initial_volume: source_definition.initial_volume,
              validity_start_date: source_definition.validity_start_date,
              validity_end_date: source_definition.validity_end_date,
              critical_state: source_definition.critical_state,
              critical_threshold: source_definition.critical_threshold,
              description: source_definition.description,
              quota_order_number_id: order_number.quota_order_number_id,
              quota_order_number_sid: order_number.quota_order_number_sid,
              measurement_unit_code: source_definition.measurement_unit_code,
              measurement_unit_qualifier_code: source_definition.measurement_unit_qualifier_code,
              workbasket_type_of_quota: source_definition.workbasket_type_of_quota
          )
          ::WorkbasketValueObjects::Shared::PrimaryKeyGenerator.new(definition).assign!
          settings_saver.assign_system_ops!(definition)
          if definition.save
            add_measures_for_definition!(
                ops[index.to_s]['commodity_codes'],
                source_definition.validity_start_date,
                source_definition.validity_end_date)
          end
        end
      end

      private
      def build_order_number!(order_number_ops)
        ::WorkbasketServices::QuotaSavers::OrderNumber.new(
            settings_saver, order_number_ops, true
        )
      end

      def build_quota_association!(sub_quota, coefficient)
        QuotaAssociation.unrestrict_primary_key
        association = QuotaAssociation.new(
            main_quota_definition_sid: parent_quota.quota_order_number_sid,
            sub_quota_definition_sid: sub_quota.quota_order_number_sid,
            relation_type: 'EQ',
            coefficient: coefficient,
        )
        settings_saver.assign_system_ops!(association)
        association.save
      end

      def add_measures_for_definition!(goods_nomenclature_codes, start_point, end_point)
        Array.wrap(base_params['geographical_area_id']).each do |geographical_area_id|
          Array.wrap(goods_nomenclature_codes).each do |goods_nomenclature_code|
            attrs_parser.instance_variable_set(:@start_date, start_point)
            attrs_parser.instance_variable_set(:@end_date, end_point)
            if period_measure_components.present?
              attrs_parser.instance_variable_set(
                  :@measure_components,
                  period_measure_components
              )
            end
            settings_saver.send(:candidate_validation_errors, {
                geographical_area_id: geographical_area_id,
                goods_nomenclature_code: goods_nomenclature_code,
            })
          end
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

      def duty_expression_list
        source("duties_each_period")["duty_expressions"]
      end

      def source(key)
        @section_ops[key] == "true" ? @balance_ops : @section_ops
      end

    end
  end
end