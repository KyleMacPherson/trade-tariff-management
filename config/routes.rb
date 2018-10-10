require "sidekiq/web"

Rails.application.routes.draw do
  mount Sidekiq::Web, at: "sidekiq"

  root to: 'workbaskets#index'

  get "healthcheck" => "healthcheck#index"

  resources :workbaskets, only: [:index]

  namespace :xml_generation do
    resources :exports, only: [:index, :show, :create]
  end

  namespace :db do
    resources :rollbacks, only: [:index, :create]
  end

  resources :goods_nomenclatures, only: [:index]
  resources :regulations, only: [:index]
  resources :duty_expressions, only: [:index]
  resources :quota_order_numbers, only: [:index]

  scope module: :additional_codes do
    resources :additional_codes, only: [:index] do
      collection do
        post :search

        get :preview
      end
    end

    resources :additional_code_types, only: [:index]
  end

  namespace :additional_codes do
    resources :bulks, only: [:show, :create, :edit, :update, :destroy] do
      member do
        get '/work_with_selected', to: "bulks#work_with_selected"
        post '/work_with_selected', to: "bulks#persist_work_with_selected"
        get :submitted_for_cross_check

        resources :bulk_items, only: [] do
          collection do
            get :validation_details
            post :remove_items
          end
        end
      end
    end
  end

  scope module: :certificates do
    resources :certificates, only: [:index]
    resources :certificate_types, only: [:index]
  end

  scope module: :footnotes do
    resources :footnote_types, only: [:index]
    resources :footnotes, only: [:index]
  end

  scope module: :quotas do
    resources :quotas, only: [:index] do
      collection do
        post :search
      end
    end
  end

  namespace :quotas do
    resources :bulks, only: [:show, :create, :edit, :update, :destroy] do
      member do
        get '/work_with_selected', to: "bulks#work_with_selected"
        post '/work_with_selected', to: "bulks#persist_work_with_selected"
      end
    end
  end

  scope module: :measures do
    resources :measures, only: [:index] do
      collection do
        post :search

        get :quick_search
        get :all_measures_data
      end
    end

    resources :measure_types, only: [:index]
    resources :measure_type_series, only: [:index]
    resources :measure_condition_codes, only: [:index]
    resources :measure_actions, only: [:index]
    resources :measurement_units, only: [:index]
    resources :measurement_unit_qualifiers, only: [:index]
    resources :monetary_units, only: [:index]
    resources :geographical_areas, only: [:index]
  end

  namespace :measures do
    resources :bulks, only: [:show, :create, :edit, :update, :destroy] do
      member do
        get '/work_with_selected_measures', to: "bulks#work_with_selected_measures"
        post '/work_with_selected_measures', to: "bulks#persist_work_with_selected_measures"
        get :submitted_for_cross_check

        resources :bulk_items, only: [] do
          collection do
            get :validation_details
            post :remove_items
          end
        end
      end
    end
  end

  scope module: :workbaskets do
    resources :workbaskets, only: [] do
      member do
        resource :schedule_export_to_cds, only: [:new, :create]
        resource :cross_check, only: [:new, :create, :show]
        resource :approve, only: [:new, :create, :show]
        resource :workflow_transitions, only: [] do
          post :submit_for_approval
        end
      end
    end

    resources :create_additional_code, only: [:new, :show, :edit, :update, :destroy] do
      member do
        get :submitted_for_cross_check
        get :move_to_editing_mode
        get :withdraw_workbasket_from_workflow
      end
    end

    resources :create_regulation, only: [:new, :show, :edit, :update, :destroy] do
      member do
        put :attach_pdf

        get :submitted_for_cross_check
        get :move_to_editing_mode
        get :withdraw_workbasket_from_workflow
      end
    end

    resources :create_geographical_area, only: [:new, :show, :edit, :update, :destroy] do
      member do
        post :validate_group_memberships
        post :validate_country_or_region_memberhips
        post :validate_membership

        get :submitted_for_cross_check
        get :move_to_editing_mode
        get :withdraw_workbasket_from_workflow
      end
    end

    resources :create_measures, only: [:new, :show, :edit, :update, :destroy] do
      member do
        get :submitted_for_cross_check
        get :move_to_editing_mode
        get :withdraw_workbasket_from_workflow
      end
    end

    resources :create_quota, only: [:new, :show, :edit, :update, :destroy] do
      member do
        get :submitted_for_cross_check
        get :move_to_editing_mode
        get :withdraw_workbasket_from_workflow
      end
    end
  end

  namespace :regulation_form_api do
    resources :regulation_groups, only: [:index]
    resources :base_regulations, only: [:index]
  end

  resources :users, only: [:index]
end
