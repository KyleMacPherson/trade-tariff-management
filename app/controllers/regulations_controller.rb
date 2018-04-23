class RegulationsController < ::BaseController

  expose(:regulation_saver) do
    regulation_ops = params[:regulation_form]
    regulation_ops.send("permitted=", true)
    regulation_ops = regulation_ops.to_h

    ::RegulationSaver.new(current_user, regulation_ops)
  end

  expose(:regulation) do
    regulation_saver.regulation
  end

  def collection
    base_regs = BaseRegulation.q_search(:base_regulation_id, params[:q])
    mod_regs = ModificationRegulation.q_search(:modification_regulation_id, params[:q])
    base_regs.to_a.concat mod_regs.to_a
  end

  def new
    Rails.logger.info ""
    Rails.logger.info "-" * 100
    Rails.logger.info ""
    Rails.logger.info " current_user: #{current_user.inspect} "
    Rails.logger.info ""
    Rails.logger.info "-" * 100
    Rails.logger.info ""

    @form = RegulationForm.new
  end

  def create
    if regulation_saver.valid?
      regulation_saver.persist!

      redirect_to root_url
    else
      @form = RegulationForm.new nil, params[:regulation_form]
      regulation_saver.errors.each do |k,v|
        @form.errors.add(k, v)
      end

      render :new
    end
  end
end
