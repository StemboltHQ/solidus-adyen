class Spree::AdyenNotificationsController < Spree::StoreController
  skip_before_filter :verify_authenticity_token

  before_filter :authenticate

  def notify
    notification = AdyenNotification.build(params)

    if duplicate? notification
      accept and return
    end

    notification.save!
    notification.handle!

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

    # Always return that we have accepted the notification
    accept
  end

  protected
  # Enable HTTP basic authentication
  def authenticate
    authenticate_or_request_with_http_basic do |username, password|
      username == ENV['ADYEN_NOTIFY_USER'] && password == ENV['ADYEN_NOTIFY_PASSWD']
    end
  end

  private
  def accept
    render text: "[accepted]"
  end

  def duplicate? notification
    AdyenNotification.exists?(
      psp_reference: notification.psp_reference,
      event_code: notification.event_code,
      success: notification.success
    )
  end
end
