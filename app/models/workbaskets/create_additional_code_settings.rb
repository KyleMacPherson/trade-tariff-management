module Workbaskets
  class CreateAdditionalCodeSettings < Sequel::Model(:create_additional_code_workbasket_settings)

    include ::WorkbasketHelpers::SettingsBase

    def collection_models
      %w(
        AdditionalCode
        AdditionalCodeDescription
        AdditionalCodeDescriptionPeriod
      )
    end

    def settings
      JSON.parse(main_step_settings_jsonb)
    end

    def measure_sids_jsonb
      '{}'
    end

  end
end
