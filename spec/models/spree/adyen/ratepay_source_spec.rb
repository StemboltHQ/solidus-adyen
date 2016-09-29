require 'spec_helper'

describe Spree::Adyen::RatepaySource do
  it { is_expected.to belong_to(:payment_method) }
  it { is_expected.to belong_to(:user) }
  it { is_expected.to have_one(:payment) }
  it { is_expected.to have_many(:notifications) }

  subject { build_stubbed :ratepay_source, dob_day: "01", dob_month: "02", dob_year: "1983" }

  describe "#date_of_birth" do
    it "returns the formatted date of birth" do
      expect(subject.date_of_birth).to eq "1983-01-02"
    end
  end
end
