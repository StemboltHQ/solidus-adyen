module Spree
  module Api
    module Adyen
      class HppsController < Spree::Api::BaseController
        include Spree::Adyen::HasHppDirectory

        def directory
          render json: @brands
        end
      end
    end
  end
end
