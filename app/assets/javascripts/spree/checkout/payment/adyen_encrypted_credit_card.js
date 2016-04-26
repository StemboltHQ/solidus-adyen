Spree.createEncryptedAdyenForm = function(paymentMethodId) { 
  document.addEventListener("DOMContentLoaded", function() {
    var checkout_form = document.getElementById("checkout_form_payment")
      // See adyen.encrypt.simple.html for details on the options to use
    var options = {
      name: "payment_source[" + paymentMethodId + "][encrypted_credit_card_data]",
      enableValidations : true,
      // If there's other payment methods, they need to be able to submit
      submitButtonAlwaysEnabled: true,
      disabledValidClass: true
    };
    // Create the form.
    // Note that the method is on the Adyen object, not the adyen.encrypt object.
    return adyen.createEncryptedForm(checkout_form, options);
  });
}
