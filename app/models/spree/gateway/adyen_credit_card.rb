module Spree
  class Gateway::AdyenCreditCard < Gateway
    preference :api_username, :string
    preference :api_password, :string
    preference :merchant_account, :string
    preference :cse_token, :string

    def merchant_account
      ENV["ADYEN_MERCHANT_ACCOUNT"] || preferred_merchant_account
    end

    def method_type
      "adyen_encrypted_cc"
    end

    def cse_token
      ENV["ADYEN_CSE_TOKEN"] || preferred_cse_token
    end

    def provider_class
      ::Adyen::API
    end

    def provider
      ::Adyen.configuration.api_username =
        (ENV["ADYEN_API_USERNAME"] || preferred_api_username)
      ::Adyen.configuration.api_password =
        (ENV["ADYEN_API_PASSWORD"] || preferred_api_password)
      ::Adyen.configuration.default_api_params[:merchant_account] =
        merchant_account

      provider_class
    end
  end
end
