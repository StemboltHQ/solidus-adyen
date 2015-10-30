shared_context "mock adyen api" do |success:, fault_message: "", psp_reference: ""|
  before do
    allow_any_instance_of(Spree::Gateway::AdyenHPP).
      to receive(:provider).
      and_return provider
  end

  let(:provider) do
    mock_response = -> (method) {
      response(method, success, fault_message, psp_reference)
    }

    instance_double("Adyen::API").tap do |double|
      allow(double).
        to receive(:capture_payment).
        with(
          kind_of(String),
          hash_including(:currency, :value)
        ).
        and_return(mock_response.("capture"))

      allow(double).
        to receive(:cancel_or_refund_payment).
        with(kind_of(String)).
        and_return(mock_response.("cancel_or_refund"))

      allow(double).
        to receive(:refund_payment).
        with(
          kind_of(String),
          hash_including(:currency, :value)
        ).
        and_return(mock_response.("refund"))
    end
  end

  def response(method, success, fault_message, ref = nil)
    ref ||= "%016d" % SecureRandom.random_number(10**16)

    instance_double(
      "Adyen::API::PaymentService::#{method.camelcase}Response",
      success?: success,
      fault_message: fault_message,
      params: {
        psp_reference: ref,
        response: "[#{method.camelcase(:lower)}-received]"
      }
    )
  end
end
