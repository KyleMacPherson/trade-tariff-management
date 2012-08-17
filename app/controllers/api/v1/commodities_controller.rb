module Api
  module V1
    class CommoditiesController < ApplicationController

      def show
        @commodity = Commodity.actual
                              .declarable
                              .by_code(params[:id])
                              .take

        @measures = @commodity.measures_dataset.eager({geographical_area: [:geographical_area_description, :children_geographical_areas]},
                                                      {footnotes: :footnote_description},
                                                      {measure_type: :measure_type_description},
                                                      {measure_components: [:duty_expression,
                                                                            {measurement_unit: :measurement_unit_description},
                                                                            :monetary_unit,
                                                                            :measurement_unit_qualifier]},
                                                      {measure_conditions: [{measure_action: :measure_action_description},
                                                                            {certificate: :certificate_description},
                                                                            {measurement_unit: :measurement_unit_description},
                                                                            :monetary_unit,
                                                                            :measurement_unit_qualifier,
                                                                            :measure_condition_code,
                                                                            :measure_condition_components]},
                                                      :quota_order_number,
                                                      {excluded_geographical_areas: :geographical_area_description},
                                                      :additional_code).all

        respond_with @commodity
      end
    end
  end
end
