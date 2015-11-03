module Spree::Adyen::URL
  def self.payment_adyen_customer_area_url(psp_reference:, merchant_account:)
    ::URI::HTTPS.build(
      host: "ca-test.adyen.com",
      path: "/ca/ca/accounts/showTx.shtml",
      query:
      { txType: "Payment",
        accountKey: "MerchantAccount.#{merchant_account}",
        pspReference: psp_reference
      }.to_query
    ).to_s
  end

  def self.modify_search_url(query:)
    ::URI::HTTPS.build(
      host: "ca-test.adyen.com",
      path: "/ca/ca/payments/modifySearch.shtml",
      query:
      { uxEvent: "PAYMENT_SEARCH",
        query: query,
        search: "Search"
      }.to_query
    ).to_s
  end
end
