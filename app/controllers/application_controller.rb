class ApplicationController < ActionController::Base
  protect_from_forgery

  respond_to :json, :html

  around_filter :configure_time_machine

  unless Rails.application.config.consider_all_requests_local
    rescue_from Exception,                           with: :render_error
    rescue_from Sequel::RecordNotFound,              with: :render_not_found
    rescue_from ActionController::RoutingError,      with: :render_not_found
    rescue_from ActionController::UnknownController, with: :render_not_found
    rescue_from ActionController::UnknownAction,     with: :render_not_found
  end

  def render_not_found
    respond_to do |format|
      format.html {
        render text: "404 - Not Found", status: 404
      }
      format.json {
        render json: { error: "404 - Not Found" }, status: 404
      }
    end
  end

  def render_error(exception)
    notify_airbrake(exception)
    logger.error exception
    logger.error exception.backtrace

    respond_to do |format|
      format.html {
        render text: "500 - Internal Server Error: #{exception.message}", status: 500
      }
      format.json {
        render json: { error: "500 - Internal Server Error: #{exception.message}" }, status: 500
      }
    end
  end

  private

  def configure_time_machine
    TimeMachine.at(params[:as_of]) do
      yield
    end
  end
end
