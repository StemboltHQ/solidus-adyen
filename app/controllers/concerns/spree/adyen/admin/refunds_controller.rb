module Spree::Adyen::Admin::RefundsController
  extend ActiveSupport::Concern

  included do
    before_filter :adyen_create, only: [:create]
  end

  def adyen_create
    if hpp_payment?
      # this sucks, but the attributes are not assigned until after callbacks
      # if we're here we aren't going down the normal flow anyways
      @refund.attributes = permitted_resource_params

      # early exit if @refund is invalid, .create will have the error messages
      return if @refund.invalid?

      @payment.refunds.reset # we don't want to save the refund
      @payment.adyen_hpp_credit!(cents, currency: currency)

      respond
    end
  end

  private

  def currency
    money.currency.iso_code
  end

  def cents
    money.cents
  end

  def money
    @refund.money.money
  end

  def hpp_payment?
    @refund.payment.source.class == Spree::Adyen::HppSource
  end

  # This is directly copied from .create's response, no way to make it any
  # less awful than this as we still want it to have the same response.
  def respond
    respond_with(@object) do |format|
      format.html do
        flash[:success] = "Refund request was received"
        redirect_to location_after_save
      end
      format.js { render :layout => false }
    end
  end
end
