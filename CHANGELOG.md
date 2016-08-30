# Changelog

### Unreleased changes

*   Switch from using the SOAP API to the REST API for all payment requests [#91](https://github.com/StemboltHQ/solidus-adyen/pull/91)

    * all payments previously used the Adyen gem's SOAP API implementation, which
      consisted of concatenating a number of XML string partials [example](https://github.com/wvanbergen/adyen/blob/master/lib/adyen/api/templates/payment_service.rb)
    * the SOAP implementation made it almost impossible to customize the request
      parameters beyond those supported, but the REST API allows passing in
      arbitrary parameters
*   credit! now receives full `gateway_options` when called from admin/refunds_controller#create
*   credit includes `:additional_data` in the request if it's provided in options
*   Add `Spree::Adyen::ApiResponse` class to wrap various response classes
    returned by the Adyen gem
*   Add `Spree::Adyen::Client` class as an interface for making API requests
