module Spree
  module Adyen
    module Form
      class Configuration
        attr_accessor :params_class

        # This class allows us to provide configuration options to the
        # Spree::Adyen::Form module. To add extra options, add an attr_accessor
        # and provide a default value.
        #
        # Users can configure these options inside an initializer as follows:
        #   Spree::Adyen::Form.configure do |config|
        #     config.params_class = Some::Custom::Class
        #   end
        def initialize
          @params_class = Spree::Adyen::Form::Params
        end
      end
    end
  end
end
