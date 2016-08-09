shared_context "mock adyen api" do |success:, fault_message: "", psp_reference: "", klass: Spree::Gateway::AdyenHPP |
  before do
    allow_any_instance_of(klass).
      to receive(:provider).
      and_return provider
  end

  let(:provider) do
    # lambda so that this doesn't leak outside of this context.
    mock_response = lambda do |method|
      psp_reference ||= format "%016d", SecureRandom.random_number(10**16)

      instance_double(
        "Adyen::API::PaymentService::#{method.camelcase}Response",
        success?: success,
        fault_message: fault_message,
        params: {
          psp_reference: psp_reference,
          response: "[#{method.camelcase(:lower)}-received]"
        }
      )
    end

    instance_double("Adyen::API").tap do |double|
      allow(double).
        to receive(:authorise_payment).
        with(
          kind_of(String),
          hash_including(:currency, :value),
          hash_including(:reference, :email, :ip, :statement),
          hash_including(:encrypted),
          true,
          nil,
          false,
          hash_including(:street, :house_number_or_name, :city, :postal_code, :state_or_province, :country)
        ).
        and_return(mock_response.call("authorise"))

      allow(double).
        to receive(:authorise_recurring_payment).
        with(
          kind_of(String),
          hash_including(:currency, :value),
          hash_including(:reference, :email, :ip, :statement),
          kind_of(String),
          nil,
          false,
          hash_including(:street, :house_number_or_name, :city, :postal_code, :state_or_province, :country)
      ).and_return(mock_response.call("authorise"))

      allow(double).
        to receive(:capture_payment).
        with(
          kind_of(String),
          hash_including(:currency, :value)
        ).
        and_return(mock_response.call("capture"))

      allow(double).
        to receive(:cancel_or_refund_payment).
        with(kind_of(String)).
        and_return(mock_response.call("cancel_or_refund"))

      allow(double).
        to receive(:refund_payment).
        with(
          kind_of(String),
          hash_including(:currency, :value)
      ).
      and_return(mock_response.call("refund"))

      allow(double).
        to receive(:list_recurring_details).
        with(kind_of(String)).
        and_return(double("recurring details", details: [
          { creation_date: Time.parse("2016-07-29 UTC"),
            recurring_detail_reference: "AWESOMEREFERENCE",
            variant: "amex",
            card: {
              number: "0000",
              expiry_date: Time.parse("2016-10-21 UTC"),
              holder_name: "Batman Dananana",
            },
          }
        ]))
    end
  end
end
