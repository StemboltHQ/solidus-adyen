require 'spec_helper'

RSpec.describe Spree::Adyen::HppSource do
  it { is_expected.to belong_to(:order) }
  it { is_expected.to have_one(:payment) }
  it { is_expected.to have_many(:notifications) }
end
