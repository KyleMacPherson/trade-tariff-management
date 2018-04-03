require 'api_constraints'
require "sidekiq/web"

Rails.application.routes.draw do
  mount Sidekiq::Web, at: "sidekiq"

  get 'home/index'
  get "healthcheck" => "healthcheck#index"

  namespace :api, defaults: {format: 'json'}, path: "/" do
    # How (or even if) API versioning will be implemented is still an open question. We can defer
    # the choice until we need to expose the API to clients which we don't control.
    scope module: :v1, constraints: ApiConstraints.new(version: 1, default: true) do
     # TODO
    end
  end

  namespace :xml_generation do
    resources :exports, only: [:index, :show, :create]
  end

  scope module: :measures do
    resources :measures
    resources :certificates, only: [:index]
    resources :certificate_types, only: [:index]
    resources :regulations, only: [:index]
    resources :measure_types, only: [:index]
    resources :measure_type_series, only: [:index]
    resources :measure_condition_codes, only: [:index]
    resources :goods_nomenclatures, only: [:index]
    resources :additional_codes, only: [:index]
    resources :additional_code_types, only: [:index]
    resources :duty_expressions, only: [:index]
    resources :measure_actions, only: [:index]
    resources :measurement_units, only: [:index]
    resources :measurement_unit_qualifiers, only: [:index]
    resources :footnote_types, only: [:index]
    resources :footnotes, only: [:index]
  end

  root to: 'home#index'
end
