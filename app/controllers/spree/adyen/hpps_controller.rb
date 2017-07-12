module Spree
  module Adyen
    class HppsController < Spree::AdyenController
      include Spree::Adyen::HasHppDirectory

      layout false

      def directory
        respond_to do |format|
          format.html
          format.json { render json: @brands }
        end
      end
    end
  end
end
