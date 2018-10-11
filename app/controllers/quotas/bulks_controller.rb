module Quotas
  class BulksController < Measures::BulksBaseController

    # include ::SearchCacheHelpers

    before_action :require_to_be_workbasket_owner!, only: [
        :update, :destroy
    ]

    # expose(:separator) do
    #   "_BEQ_"
    # end

    # expose(:current_page) do
    #   params[:page]
    # end

    expose(:main_step_settings) do
      {
        start_date: params[:validity_start_date],
        workbasket_action: params[:workbasket_action],
        regulation: params[:regulation_id].blank? ? nil : ::BaseOrModificationRegulationSearch.new(params[:regulation_id]).result.first.try(:to_json),
        regulation_id: params[:regulation_id],
        regulation_role: params[:regulation_role],
        reason: params[:reason],
        title: params[:workbasket_name]
      }
    end

    expose(:workbasket_settings) do
      workbasket.settings
    end

    expose(:edit_url) do
      edit_quotas_bulk_url(
          workbasket.id
      )
    end

    # expose(:submit_group_for_cross_check) do
    #   params[:mode] == "save_group_for_cross_check"
    # end

    # expose(:final_saving_batch) do
    #   params[:final_batch].to_s == "true"
    # end

    # expose(:workbasket_container) do
    #   ::Quotas::Workbasket::Items.new(
    #       workbasket, cached_search_ops
    #   ).prepare
    # end

    # expose(:cached_search_ops) do
    #   if workbasket_settings.initial_items_populated.present?
    #     {
    #         quota_sids: workbasket_items.pluck(:record_id),
    #         page: current_page
    #     }
    #   else
    #     Rails.cache.read(params[:search_code]).merge(
    #         page: current_page
    #     )
    #   end
    # end

    # expose(:pagination_metadata) do
    #   {
    #       page: search_results.current_page,
    #       total_count: search_results.total_count,
    #       per_page: search_results.limit_value
    #   }
    # end

    # expose(:search_results) do
    #   workbasket_container.pagination_metadata
    # end

    # expose(:json_collection) do
    #   workbasket_container.collection
    # end

    # expose(:search_ops) do
    #   {
    #       quota_sids: ::QuotaService::FetchQuotaSids.new(params).ids
    #   }
    # end

    # expose(:bulk_quotas_collection) do
    #   JSON.parse(request.body.read)["bulk_quotas_collection"]
    # end

    # expose(:bulk_saver) do
    #   ::Quotas::BulkSaver.new(
    #       current_user,
    #       workbasket,
    #       bulk_quotas_collection
    #   )
    # end

    def edit
      # if search_mode?
      #   respond_to do |format|
      #     format.json { render json: json_response }
      #     format.html
      #   end
      #
      # else
      #   redirect_to edit_url
      # end
    end

    def create
      self.workbasket = Workbaskets::Workbasket.new(
          status: :new_in_progress,
          type: :bulk_edit_of_quotas,
          user: current_user
      )

      if workbasket.save
        workbasket_settings.update(
            initial_search_results_code: params[:search_code],
            quota_sid: params[:quota_sids].first
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
      puts "!!! #{main_step_settings.inspect}"
      workbasket_settings.set_settings_for!("main", main_step_settings)
      workbasket_settings.set_workbasket_system_data!

      redirect_to edit_url
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