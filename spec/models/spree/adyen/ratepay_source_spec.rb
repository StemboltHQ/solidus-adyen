require 'spec_helper'

describe Spree::Adyen::RatepaySource do
  it { is_expected.to belong_to(:payment_method) }
  it { is_expected.to belong_to(:user) }
  it { is_expected.to have_one(:payment) }
  it { is_expected.to have_many(:notifications) }
end
