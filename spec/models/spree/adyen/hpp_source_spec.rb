require 'spec_helper'

RSpec.describe Spree::Adyen::HppSource do
  it { is_expected.to have_one(:payment) }
end
