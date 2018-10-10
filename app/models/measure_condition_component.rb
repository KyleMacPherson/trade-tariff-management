class MeasureConditionComponent < Sequel::Model

  include ::XmlGeneration::BaseHelper
  include ::WorkbasketHelpers::Association
  include ::ForceValidatorConcern

  plugin :time_machine
  plugin :oplog, primary_key: [:measure_condition_sid,
                               :duty_expression_id]
  plugin :conformance_validator

  set_primary_key [:measure_condition_sid, :duty_expression_id]

  one_to_one :measure_condition, key: :measure_condition_sid,
                                 primary_key: :measure_condition_sid

  one_to_one :duty_expression, key: :duty_expression_id,
                               primary_key: :duty_expression_id do |ds|
    ds.with_actual(DutyExpression)
  end

  one_to_one :measurement_unit, key: :measurement_unit_code,
                                primary_key: :measurement_unit_code do |ds|
    ds.with_actual(MeasurementUnit)
  end

  one_to_one :monetary_unit, key: :monetary_unit_code,
                             primary_key: :monetary_unit_code do |ds|
    ds.with_actual(MonetaryUnit)
  end

  one_to_one :measurement_unit_qualifier, key: :measurement_unit_qualifier_code,
                                          primary_key: :measurement_unit_qualifier_code do |ds|
    ds.with_actual(MeasurementUnitQualifier)
  end

  delegate :description, :abbreviation, to: :duty_expression, prefix: true
  delegate :abbreviation, to: :monetary_unit, prefix: true, allow_nil: true
  delegate :description, to: :monetary_unit, prefix: true, allow_nil: true
  delegate :validity_start_date, :validity_end_date, to: :measure_condition, allow_nil: true

  def formatted_duty_expression
    DutyExpressionFormatter.format({
      duty_expression_id: duty_expression_id,
      duty_expression_description: duty_expression_description,
      duty_expression_abbreviation: duty_expression_abbreviation,
      duty_amount: duty_amount,
      monetary_unit: monetary_unit_code,
      monetary_unit_abbreviation: monetary_unit_abbreviation,
      measurement_unit: measurement_unit,
      measurement_unit_qualifier: measurement_unit_qualifier
    })
  end

  def record_code
    "430".freeze
  end

  def subrecord_code
    "11".freeze
  end

  def to_json(options = {})
    {
      original_duty_expression_id: original_duty_expression_id,
      duty_amount: duty_amount,
      duty_expression: duty_expression.to_json,
      measurement_unit: measurement_unit.to_json,
      monetary_unit: monetary_unit.to_json,
      measurement_unit_qualifier: measurement_unit_qualifier.to_json,
    }
  end
end
