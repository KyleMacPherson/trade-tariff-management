module AdditionalCodes
  class AdditionalCodesController < ::BaseController

    expose(:additional_code) do
      AdditionalCode.by_code(params[:code])
    end

    def collection
      AdditionalCode.q_search(params)
    end

    def preview
      if additional_code.present?
        render partial: "measures/bulks/additional_code_preview"
      else
        head :not_found
      end
    end
  end
end
