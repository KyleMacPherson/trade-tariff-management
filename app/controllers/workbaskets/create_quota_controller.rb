module Workbaskets
  class CreateQuotaController < Workbaskets::BaseController
    expose(:sub_klass) { "CreateQuota" }
    expose(:settings_type) { :create_quota }

    expose(:initial_step_url) do
      edit_create_quotum_url(
        workbasket.id,
        step: :main
      )
    end

    expose(:previous_step_url) do
      edit_create_quotum_url(
        workbasket.id,
        step: previous_step
      )
    end

    expose(:read_only_section_url) do
      create_quotum_url(workbasket.id)
    end

    expose(:submitted_url) do
      submitted_for_cross_check_create_quotum_url(workbasket.id)
    end

    expose(:quota_periods) do
      workbasket_settings.quota_periods
    end

    expose(:parent_quota_periods) do
      workbasket_settings.parent_quota_periods
    end

  private

    def check_if_action_is_permitted!
      if (
           step_pointer.conditions_footnotes? ||
           step_pointer.review_and_submit_step?
         ) &&
          !workbasket_settings.validations_passed?(previous_step)

        redirect_to previous_step_url
        false
      end
    end

    def workbasket_data_can_be_persisted?
      step_pointer.conditions_footnotes? &&
        saver_mode == 'continue'
    end
  end
end
