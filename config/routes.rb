class AdyenHppDirectoryConstraint
  def matches?(request)
    request.params[:payment_method_id].present? && request.params[:order_id].present?
  end
end

Spree::Core::Engine.routes.draw do
  namespace :adyen do
    resource :hpp, only: [] do
      member do
        get :directory
      end
    end
  end

  get 'checkout/payment/adyen', to: 'adyen_redirect#confirm', as: :adyen_confirmation
  post 'adyen/notify', to: 'adyen_notifications#notify'
  post 'adyen/authorise3d', to: 'adyen_redirect#authorise3d', as: :adyen_authorise3d

  namespace :api, defaults: {format: 'json'} do
    namespace :adyen do
      get 'hpp/directory', to: 'hpps#directory', constraints: AdyenHppDirectoryConstraint.new
      get 'payment/confirm', to: 'redirect#confirm', as: :api_adyen_confirmation
    end
  end
end
