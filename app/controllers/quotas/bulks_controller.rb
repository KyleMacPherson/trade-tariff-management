module Quotas
  class BulksController < Measures::BulksBaseController

    before_action :require_to_be_workbasket_owner!, only: [
        :update, :destroy
    ]

    expose(:current_page) do
      params[:page]
    end

    expose(:main_step_settings) do
      {
        start_date: params[:validity_start_date],
        workbasket_action: params[:workbasket_action],
        regulation: params[:regulation_id].blank? ? nil : ::BaseOrModificationRegulationSearch.new(params[:regulation_id]).result.first.try(:to_json),
        regulation_id: params[:regulation_id],
        regulation_role: params[:regulation_role],
        reason: params[:reason],
        title: params[:workbasket_name],
        suspension_date: params[:suspension_date]
      }
    end

    expose(:workbasket_settings) do
      workbasket.settings
    end

    expose(:edit_url) do
      edit_quotas_bulk_url(
          workbasket.id,
          search_code: workbasket_settings.initial_search_results_code
      )
    end

    expose(:submit_group_for_cross_check) do
      params[:mode] == "save_group_for_cross_check"
    end

    expose(:final_saving_batch) do
      params[:final_batch].to_s == "true"
    end

    expose(:workbasket_container) do
      ::Measures::Workbasket::Items.new(
          workbasket, cached_search_ops
      ).prepare
    end

    expose(:cached_search_ops) do
      if workbasket_settings.initial_items_populated.present?
        {
            measure_sids: workbasket_items.pluck(:record_id),
            page: current_page
        }
      else
        {
            measure_sids: ::Measures::Search.new(measures_search_ops).measure_sids,
            page: current_page
        }
      end
    end

    expose(:pagination_metadata) do
      {
          page: search_results.current_page,
          total_count: search_results.total_count,
          per_page: search_results.limit_value
      }
    end

    expose(:search_results) do
      workbasket_container.pagination_metadata
    end

    expose(:json_collection) do
      workbasket_container.collection
    end

    expose(:measures_search_ops) do
      {
          'order_number': {
              'enabled': '1',
              'operator': 'is',
              'value': workbasket_settings.quota_definition.quota_order_number_id
          },
          'valid_to': {
              'enabled': '1',
              'operator': 'is_after_or_nil',
              'value': workbasket.operation_date
          }
      }
    end

    expose(:edit_quota_ops) do
      ops = params[:settings]
      ops.send("permitted=", true) if ops.present?
      ops = (ops || {}).to_h

      ops
    end

    expose(:edit_quota_measures_ops) do
      JSON.parse(request.body.read)["bulk_measures_collection"]
    end

    expose(:remove_suspension_ops) do
      {}
    end

    expose(:stop_quota_ops) do
      {}
    end

    expose(:suspend_quota_ops) do
      {}
    end

    WORKBASKET_ACTION_SAVER = {
        'edit_quota' => '::',
        'edit_quota_measures' => '::Measures::BulkSaver',
        'remove_suspension' => '::Quotas::UnSuspendSaver',
        'stop_quota' => '::Quotas::StopSaver',
        'suspend_quota' => '::Quotas::SuspendSaver'
    }

    expose(:bulk_saver) do
      WORKBASKET_ACTION_SAVER[workbasket_settings.workbasket_action].constantize.new(
          current_user,
          workbasket,
          send("#{workbasket_settings.workbasket_action}_ops")
      )
    end

    expose(:json_response) do
      {
          collection: json_collection,
          total_pages: search_results.total_pages,
          current_page: search_results.current_page,
          has_more: !search_results.last_page?
      }
    end

    def edit
      respond_to do |format|
        format.json { render json: json_response }
        format.html
      end
    end

    def create
      self.workbasket = Workbaskets::Workbasket.new(
          status: :new_in_progress,
          type: :bulk_edit_of_quotas,
          user: current_user
      )

      if workbasket.save
        quota_sid = params[:quota_sids].first
        quota_settings = ::WorkbasketInteractions::EditOfQuota::SettingsExtractor.new(quota_sid).settings
        workbasket_settings.update(
            initial_search_results_code: params[:search_code],
            quota_sid: quota_sid,
            quota_settings_jsonb: quota_settings.to_json
        )

        redirect_to work_with_selected_quotas_bulk_url(
                        workbasket.id
                    )
      else
        redirect_to quotas_url(
                        notice: "You have to select 1 quota from list!"
                    )
      end
    end

    def persist_work_with_selected
      workbasket_settings.set_settings_for!("main", main_step_settings)
      workbasket_settings.set_workbasket_system_data!

      if workbasket_settings.editable_workbasket?
        redirect_to edit_url
      else
        if bulk_saver.valid?
          bulk_saver.persist!

          redirect_to quotas_url(
                          search_code: workbasket_settings.initial_search_results_code,
                          previous_workbasket_id: workbasket.id
                      )
        end
      end
    end

    def update
      if bulk_saver.valid?
        if submit_group_for_cross_check && final_saving_batch
          bulk_saver.persist!

          render json: bulk_saver.success_response.merge(
              redirect_url: submitted_for_cross_check_quotas_bulk_url(workbasket.id)
          ), status: :ok
        else
          render json: bulk_saver.success_response,
                 status: :ok
        end
      else
        render json: bulk_saver.error_response,
               status: :unprocessable_entity
      end
    end

    def destroy
      workbasket.destroy

      render json: {}, head: :ok
    end

  end
end
