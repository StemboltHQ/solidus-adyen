Spree::Payment.class_eval do
  include Spree::Adyen::Payment
end
