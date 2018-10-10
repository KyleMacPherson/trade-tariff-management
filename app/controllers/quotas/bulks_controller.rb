module Quotas
  class BulksController < Measures::BulksBaseController

    include ::SearchCacheHelpers

    expose(:separator) do
      "_BEQ_"
    end

    expose(:current_page) do
      params[:page]
    end

    expose(:main_step_settings) do
      {
        regulation: params[:regulation_id].blank? ? nil : ::BaseOrModificationRegulationSearch.new(params[:regulation_id]).result.first.try(:to_json),
        regulation_id: params[:regulation_id],
        regulation_role: params[:regulation_role],
        start_date: params[:start_date],
        reason: params[:reason],
        title: params[:title]
      }
    end

    expose(:workbasket_settings) do
      workbasket.settings
    end

    expose(:edit_url) do
      edit_quotas_bulk_url(
          workbasket.id,
          search_code: workbasket_settings.search_code
      )
    end

    expose(:submit_group_for_cross_check) do
      params[:mode] == "save_group_for_cross_check"
    end

    expose(:search_ops) do
      {
          quota_sids: ::QuotaService::FetchQuotaSids.new(params).ids
      }
    end

    expose(:search_results) do
      workbasket_container.pagination_metadata
    end

    expose(:json_collection) do
      workbasket_container.collection
    end

    expose(:workbasket_container) do
      ::Quotas::Workbasket::Items.new(
          workbasket, cached_search_ops
      ).prepare
    end

    def edit
      if search_mode?
        respond_to do |format|
          format.json { render json: json_response }
          format.html
        end

      else
        redirect_to edit_url
      end
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
            search_code: search_code
        )

        redirect_to work_with_selected_quotas_bulk_url(
                        workbasket.id,
                        search_code: workbasket_settings.search_code
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

      redirect_to edit_url
    end

  end
end