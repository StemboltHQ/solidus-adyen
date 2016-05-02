Spree.createEncryptedAdyenForm = function(paymentMethodId) { 
  var checkout_form = document.getElementById("checkout_form_payment")
    // See adyen.encrypt.simple.html for details on the options to use
  var options = {
    name: "payment_source[" + paymentMethodId + "][encrypted_data]",
    // We want the validations only to fire when we hit the submit button
    enableValidations : false,
    // If there's other payment methods, they need to be able to submit
    submitButtonAlwaysEnabled: true,
    disabledValidClass: true
  };

  // Create the form.
  // Note that the method is on the Adyen object, not the adyen.encrypt object.
  return adyen.createEncryptedForm(checkout_form, options);
};

Spree.attachAdyenFormSubmit = function() {
  var checkout_form = $("#checkout_form_payment");

  // Unbind all other events from submit button
  checkout_form.unbind("submit")
  checkout_form.submit(Spree.handleAdyenFormSubmit)
}

Spree.detachAdyenFormSubmit = function() {
  var checkout_form = $("#checkout_form_payment");
  checkout_form.unbind("submit")
  checkout_form.submit(Spree.disableSaveOnClick)
}
