class AllAdditionalCode < Sequel::Model

  include ::WorkbasketHelpers::Association

  plugin :time_machine

  set_primary_key  [:additional_code_sid]

  dataset_module do
    def q_search(filter_ops)
      scope = actual

      if filter_ops[:q].present?
        q_rule = "#{filter_ops[:q]}%"

        scope = scope.where("
          all_additional_codes.additional_code ilike ? OR
          all_additional_codes.description ilike ?",
                q_rule, q_rule
        )
      end

      if filter_ops[:additional_code_type_id].present?
        scope = scope.where(
            "all_additional_codes.additional_code_type_id = ?", filter_ops[:additional_code_type_id]
        )
      end

      scope.order(Sequel.asc(:all_additional_codes__additional_code))
    end

    def by_code(code=nil)
      full_code = code.to_s
                      .delete(" ")
                      .downcase

      return nil unless (full_code.present? && full_code.size == 4)

      additional_code_type_id = full_code[0]
      additional_code = full_code[1..-1]

      scope = actual.where(additional_code: additional_code)

      if additional_code_type_id.present?
        scope = scope.where("lower(additional_code_type_id) = ?", additional_code_type_id)
      end

      scope.first
    end

    include ::BulkEditHelpers::OrderByIdsQuery
    include ::AdditionalCodes::SearchFilters::FindAdditionalCodesCollection
  end

  def code
    "#{additional_code_type_id}#{additional_code}"
  end

  def status_title
    if status.present?
      I18n.t(:measures)[:states][status.to_sym]
    else
      "Imported to TARIFF"
    end
  end

  def sent_to_cds?
    status.blank? || status.to_s.in?(::Workbaskets::Workbasket::SENT_TO_CDS_STATES)
  end

  def json_mapping
    {
        additional_code: additional_code,
        type_id: additional_code_type_id,
        description: description
    }
  end

  def to_json(options = {})
    {
        additional_code_sid: additional_code_sid,
        additional_code: additional_code,
        type_id: additional_code_type_id,
        formatted_code: code,
        description: description,
        validity_start_date: validity_start_date.try(:strftime, "%d %b %Y") || "-",
        validity_end_date: validity_end_date.try(:strftime, "%d %b %Y") || "-",
        operation_date: operation_date,
        workbasket: workbasket.try(:to_json),
        status: status_title,
        sent_to_cds: sent_to_cds?
    }
  end

  def to_table_json
    to_json
  end

  class << self
    def limit_per_page
      if Rails.env.production?
        300
      elsif Rails.env.development?
        30
      elsif Rails.env.test?
        10
      end
    end

    def max_per_page
      limit_per_page
    end

    def default_per_page
      limit_per_page
    end

    def max_pages
      999
    end
  end
end