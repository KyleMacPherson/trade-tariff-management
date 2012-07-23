require 'time_machine'

class AdditionalCodeDescriptionPeriod < Sequel::Model
  plugin :time_machine

  set_primary_key [:additional_code_description_period_sid,
                   :additional_code_sid,
                   :additional_code_type_id]

  one_to_one :additional_code_description, key: [:additional_code_description_period_sid,
                                                 :additional_code_sid],
                                           primary_key: [:additional_code_description_period_sid,
                                                         :additional_code_sid]

  # many_to_one :additional_code, key: :additional_code_sid
  # many_to_one :additional_code_type, key: :additional_code_type_id
end


