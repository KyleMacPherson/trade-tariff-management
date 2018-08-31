module WorkbasketForms
  class CreateRegulationForm < ::WorkbasketForms::BaseForm

    attr_accessor :role,
                  :base_regulation_role,
                  :antidumping_regulation_role,
                  :prefix,
                  :publication_year,
                  :regulation_number,
                  :number_suffix,
                  :replacement_indicator,
                  :information_text

    def regulation_roles
      RegulationRoleTypeDescription.all.map do |role|
        [ role.regulation_role_type_id, role.description ]
      end
    end

    def prefixes
      [
          [ "C", "Draft" ],
          [ "D", "Decision" ],
          [ "A", "Agreement" ],
          [ "I", "Information" ],
          [ "J", "Judgement" ],
          [ "R", "Regulation" ]
      ]
    end

    def replacement_indicators
      {
        "0" => "Not Replaced",
        "1" => "Fully Replaced",
        "2" => "Partially Replaced"
      }
    end

  end
end