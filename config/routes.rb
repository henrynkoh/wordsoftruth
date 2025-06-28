Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  root "dashboard#index"

  resources :dashboard, only: [:index] do
    collection do
      get :job_progress
    end
    member do
      post :approve_video
      post :reject_video
    end
  end

  # Mount Sidekiq web interface
  require 'sidekiq/web'
  require 'sidekiq-scheduler/web'
  mount Sidekiq::Web => '/sidekiq'

  # Monitoring dashboard routes
  get '/monitoring', to: 'simple_monitoring#index'
  get '/monitoring/status', to: 'simple_monitoring#status'
  
  # Health check routes
  get '/health', to: 'health#check'
  get '/health/detailed', to: 'health#detailed'
  get '/health/business', to: 'health#business'
  get '/health/performance', to: 'health#performance'

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
