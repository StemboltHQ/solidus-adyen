shared_context "mock adyen client" do |success:, redirect: false, fault_message: "", psp_reference: "" |
  before do
    allow(Spree::Adyen::Client).
      to receive(:new).
      and_return(client)
  end

  let(:recurring_details_response) do
    double("recurring details", details: [
      { creation_date: Time.parse("2016-07-29 UTC"),
        recurring_detail_reference: "AWESOMEREFERENCE",
        variant: "amex",
        card_number: "0000",
        card_expiry_month: "10",
        card_expiry_year: "2016",
        card_holder_name: "Batman Dananana",
    }
    ])
  end
  let(:successful_gateway_response) do
    double("Gateway Response", success?: true, result_code: "Authorised")
  end

  let(:client) do
    api_response = lambda do |gateway_response|
      instance_double(
        "Spree::Adyen::ApiResponse",
        success?: success,
        redirect?: redirect,
        message: fault_message,
        psp_reference: psp_reference,
        attributes: { "resultCode" => "Authorised" },
        gateway_response: gateway_response,
      )
    end

    instance_double("Spree::Adyen::Client").tap do |double|
      allow(double).
        to receive(:authorise_payment).
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
      ).and_return(api_response.call(successful_gateway_response))

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
      ).and_return(api_response.call(successful_gateway_response))

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
      ).and_return(api_response.call(successful_gateway_response))

      allow(double).
        to receive(:capture_payment).
        with(
          hash_including(
            :merchant_account,
            :modification_amount,
            :original_reference,
          ),
        ).
        and_return(api_response.call(successful_gateway_response))

      allow(double).
        to receive(:cancel_payment).
        with(
          hash_including(
            :merchant_account,
            :original_reference,
          ),
        ).
        and_return(api_response.call(successful_gateway_response))

      allow(double).
        to receive(:refund_payment).
        with(
          hash_including(
            :merchant_account,
            :modification_amount,
            :original_reference,
          ),
      ).
      and_return(api_response.call(successful_gateway_response))

      allow(double).
        to receive(:list_recurring_details).
        with(hash_including(:merchant_account, :shopper_reference)).
        and_return(api_response.call(recurring_details_response))
    end
  end
end
