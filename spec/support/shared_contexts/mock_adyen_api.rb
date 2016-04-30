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
    end
  end
end
