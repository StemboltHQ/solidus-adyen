module Spree
  class AdyenNotificationsController < StoreController
    skip_before_filter :verify_authenticity_token

    before_filter :authenticate

    def notify
      response =
        ::ActiveMerchant::Billing::Response.new(
          params["success"] == "true",
          JSON.pretty_generate(params),
          {},
          {}
        )

      psp_reference =
        params["originalReference"].presence || params["pspReference"]

      Spree::Adyen::HppSource.find_by(psp_reference: psp_reference).
        try{ payment }.
        try{ log_entries }.
        try{ create!(details: YAML.dump(response)) }

      notification = AdyenNotification.log(params)
      notification.handle!
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
      # Validation failed, because of the duplicate check.
      # So ignore this notification, it is already stored and handled.
    ensure
      # Always return that we have accepted the notification
      render :text => '[accepted]'
    end

    protected
    # Enable HTTP basic authentication
    def authenticate
      authenticate_or_request_with_http_basic do |username, password|
        username == ENV['ADYEN_NOTIFY_USER'] && password == ENV['ADYEN_NOTIFY_PASSWD']
      end
    end
  end
end
