module WorkbasketInteractions
  module CreateCertificate
    class SettingsSaver

      include ::WorkbasketHelpers::SettingsSaverHelperMethods

      ATTRS_PARSER_METHODS = %w(
        certificate_type_code
        certificate_code
        description
        validity_start_date
        validity_end_date
        operation_date
      )

      attr_accessor :current_step,
                    :save_mode,
                    :settings,
                    :workbasket,
                    :settings_params,
                    :errors,
                    :attrs_parser,
                    :certificate,
                    :certificate_description,
                    :certificate_description_period,
                    :persist

      def initialize(workbasket, current_step, save_mode, settings_ops={})
        @workbasket = workbasket
        @save_mode = save_mode
        @current_step = current_step
        @settings = workbasket.settings
        @settings_params = ActiveSupport::HashWithIndifferentAccess.new(settings_ops)

        setup_attrs_parser!
        clear_cached_sequence_number!

        @persist = true # For now it always true
      end

      def save!
        workbasket.operation_date = operation_date
        workbasket.save

        settings.set_settings_for!(current_step, settings_params)
      end

      def valid?
        validate!
        @errors.blank?
      end

      def persist!
        @do_not_rollback_transactions = true
        validate!
      end

      def success_ops
        {}
      end

      ATTRS_PARSER_METHODS.map do |option|
        define_method(option) do
          attrs_parser.public_send(option)
        end
      end

      private

        def validate!
          check_initial_validation_rules!
          check_conformance_rules! if @errors.blank?
        end

        def check_initial_validation_rules!
          @errors = ::WorkbasketInteractions::CreateCertificate::InitialValidator.new(
            settings_params
          ).fetch_errors
        end

        def check_conformance_rules!
          Sequel::Model.db.transaction(@do_not_rollback_transactions.present? ? {} : { rollback: :always }) do
            add_certificate!
            add_certificate_description_period!
            add_certificate_description!
          end
        end

        def add_certificate!
          @certificate = Certificate.new(
            validity_start_date: validity_start_date,
            validity_end_date: validity_end_date
          )

          certificate.certificate_type_code = certificate_type_code
          certificate.certificate_code = certificate_code

          assign_system_ops!(certificate)
          set_primary_key!(certificate)

          certificate.save if persist_mode?
        end

        def add_certificate_description_period!
          @certificate_description_period = CertificateDescriptionPeriod.new(
            validity_start_date: validity_start_date,
            validity_end_date: validity_end_date
          )

          certificate_description_period.certificate_id = certificate.certificate_id
          certificate_description_period.certificate_type_code = certificate_type_code

          assign_system_ops!(certificate_description_period)
          set_primary_key!(certificate_description_period)

          certificate_description_period.save if persist_mode?
        end

        def add_certificate_description!
          @certificate_description = CertificateDescription.new(
            description: description
          )

          certificate_description.certificate_id = certificate.certificate_id
          certificate_description.certificate_type_code = certificate_type_code

          assign_system_ops!(certificate_description)
          set_primary_key!(certificate_description)

          certificate_description.certificate_description_period_sid = certificate_description_period.certificate_description_period_sid

          certificate_description.save if persist_mode?
        end

        def persist_mode?
          @persist.present?
        end

        def setup_attrs_parser!
          @attrs_parser = ::WorkbasketValueObjects::CreateCertificate::AttributesParser.new(
            settings_params
          )
        end
    end
  end
end
