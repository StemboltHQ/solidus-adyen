shared_context "mock adyen api" do |success:, authorised: true, received: true, fault_message: "", psp_reference: "", klass: Spree::Gateway::AdyenHPP |
  before do
    allow(Adyen::REST).
      to receive(:session).
      and_yield(client)
  end

  let(:client) do
    # lambda so that this doesn't leak outside of this context.
    authorisation_response = lambda do |method|
      psp_reference ||= format "%016d", SecureRandom.random_number(10**16)

      instance_double(
        "Adyen::REST::AuthorisePayment::Response",
        success?: success,
        authorised?: authorised,
        psp_reference: psp_reference,
        attributes: {
          psp_reference: psp_reference,
          response: "[#{method.camelcase(:lower)}-received]"
        }
      )
    end

    modification_response = lambda do |method|
      psp_reference ||= format "%016d", SecureRandom.random_number(10**16)

      instance_double(
        "Adyen::REST::ModifyPayment::Response",
        success?: success,
        received?: received,
        psp_reference: psp_reference,
        "[]": fault_message,
        attributes: {
          psp_reference: psp_reference,
          response: "[#{method.camelcase(:lower)}-received]"
        }
      )
    end

    instance_double("Adyen::REST::Client").tap do |double|
      allow(double).
        to receive(:authorise_payment).
        with(
          hash_including(
            :reference,
            :merchant_account,
            :amount,
            :billing_address,
            :additional_data,
            :shopper_i_p,
            :shopper_email,
            :shopper_reference,
          ),
        ).
        and_return(authorisation_response.call("authorise"))

      allow(double).
        to receive(:authorise_recurring_payment).
        with(
          hash_including(
            :reference,
            :merchant_account,
            :amount,
            :billing_address,
            :shopper_i_p,
            :shopper_email,
            :shopper_reference,
          ),
      ).and_return(authorisation_response.call("authorise"))

      allow(double).
        to receive(:reauthorise_recurring_payment).
        with(
          hash_including(
            :reference,
            :merchant_account,
            :amount,
            :billing_address,
            :shopper_i_p,
            :shopper_email,
            :shopper_reference,
          ),
      ).and_return(authorisation_response.call("authorise"))

      allow(double).
        to receive(:capture_payment).
        with(
          hash_including(
            :merchant_account,
            :modification_amount,
            :original_reference,
          ),
        ).
        and_return(modification_response.call("capture"))

      allow(double).
        to receive(:cancel_or_refund_payment).
        with(
          hash_including(
            :merchant_account,
            :original_reference,
          ),
        ).
        and_return(modification_response.call("cancel_or_refund"))

      allow(double).
        to receive(:refund_payment).
        with(
          hash_including(
            :merchant_account,
            :modification_amount,
            :original_reference,
          ),
      ).
      and_return(modification_response.call("refund"))

      allow(double).
        to receive(:list_recurring_details).
        with(hash_including(:merchant_account, :shopper_reference)).
        and_return(double("recurring details", details: [
          { creation_date: Time.parse("2016-07-29 UTC"),
            recurring_detail_reference: "AWESOMEREFERENCE",
            variant: "amex",
            card_number: "0000",
            card_expiry_month: "10",
            card_expiry_year: "2016",
            card_holder_name: "Batman Dananana",
          }
        ]))
    end
  end
end
