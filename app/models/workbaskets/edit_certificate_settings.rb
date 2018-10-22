module Workbaskets
  class EditCertificateSettings < Sequel::Model(:edit_certificates_workbasket_settings)
    include ::WorkbasketHelpers::SettingsBase

    def collection_models
      %w(
        Certificate
        CertificateDescriptionPeriod
        CertificateDescription
      )
    end

    def settings
      res = JSON.parse(main_step_settings_jsonb)

      if res.blank?
        res = {
          description: original_certificate.description,
          validity_start_date: original_certificate.validity_start_date.strftime("%d/%m/%Y")
        }

        if original_certificate.validity_end_date.present?
          res[:validity_end_date] = original_certificate.validity_end_date.strftime("%d/%m/%Y")
        end
      end

      res
    end

    def measure_sids_jsonb
      '{}'
    end

    def original_certificate
      @original_certificate ||= Certificate.where(
        certificate_code: original_certificate_code,
        certificate_type_code: original_certificate_type_code
      ).first
    end

    def updated_certificate
      collection_by_type(Footnote).detect do |item|
        item.certificate_code != original_certificate.certificate_code
      end
    end
  end
end
