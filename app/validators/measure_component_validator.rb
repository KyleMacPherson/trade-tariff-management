class MeasureComponentValidator < TradeTariffBackend::Validator
  #
  # TODO: We need to make sure and confirm code of this comformance rule
  #
  validation :MC1, 'Duty expression id can not be blank.', on: [:create, :update] do
    validates :presence, of: :duty_expression_id
  end

  validation :ME41, 'The referenced duty expression must exist.', on: [:create, :update] do |record|
    if record.duty_expression_id.present?
      DutyExpression.where(duty_expression_id: record.duty_expression_id).any?
    end
  end

  validation :ME42, "The validity period of the duty expression must span the validity period of the measure.", on: [:create, :update] do
    validates :validity_date_span, of: :duty_expression
  end

  validation :ME43, "The same duty expression can only be used once with the same measure.", on: [:create, :update] do
    validates :uniqueness, of: [:measure_sid, :duty_expression_id]
  end

  validation :ME45,
    %(If the flag 'amount' on duty expression is 'mandatory' then an amount must be specified.
      If the flag is set 'not permitted' then no amount may be entered."),
    on: [:create, :update] do |record|
      (
        record.duty_expression.present? &&
        record.duty_expression.duty_amount_applicability_code == 1 &&
        record.duty_amount.present?
      ) || (
        record.duty_expression.present? &&
        record.duty_expression.duty_amount_applicability_code == 2 &&
        record.duty_amount.blank?
      )
  end

  validation :ME46,
    %(If the flag 'monetary unit' on duty expression is 'mandatory' then a
      monetary unit must be specified. If the flag is set 'not permitted' then no monetary
      unit may be entered.),
    on: [:create, :update] do |record|
    (
      record.duty_expression.present? &&
      record.duty_expression.monetary_unit_applicability_code == 1 &&
      record.monetary_unit_code.present?
    ) || (
      record.duty_expression.present? &&
      record.duty_expression.monetary_unit_applicability_code == 2 &&
      record.monetary_unit_code.blank?
    )
  end

  validation :ME47,
    %(If the flag 'measurement unit' on duty expression is 'mandatory' then a measurement
      unit must be specified. If the flag is set 'not permitted' then no measurement unit
      may be entered."),
    on: [:create, :update] do |record|
    (
      record.duty_expression.present? &&
      record.duty_expression.measurement_unit_applicability_code == 1 &&
      record.measurement_unit_code.present?
    ) || (
      record.duty_expression.present? &&
      record.duty_expression.measurement_unit_applicability_code == 2 &&
      record.measurement_unit_code.blank?
    )
  end

  validation :ME48, "The referenced monetary unit must exist.", on: [:create, :update] do |record|
    if record.monetary_unit_code.present?
      MonetaryUnit.where(monetary_unit_code: record.monetary_unit_code).any?
    end
  end

  validation :ME49, "The validity period of the referenced monetary unit must span the validity period of the measure.",
    on: [:create, :update] do
    validates :validity_date_span, of: :monetary_unit
  end

  validation :ME50, "The combination measurement unit + measurement unit qualifier must exist.",
    on: [:create, :update],
    if: ->(record) { record.measurement_unit_code.present? || record.measurement_unit_qualifier_code.present? } do |record|
      record.measurement_unit.present? && record.measurement_unit_qualifier.present?
    end

  validation :ME51, "The validity period of the measurement unit must span the validity period of the measure.",
    on: [:create, :update] do
    validates :validity_date_span, of: :measurement_unit
  end

  validation :ME52, "The validity period of the measurement unit qualifier must span the validity period of the measure.",
    on: [:create, :update] do
    validates :validity_date_span, of: :measurement_unit_qualifier
  end
end
