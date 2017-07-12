module Spree
  module Adyen
    class Invoice
      # We store tax percent as a fraction (19% = 0.19)
      # This is the ratio to convert the fraction to minor units
      FRACTION_TO_MINOR_UNITS = 10000.freeze

      def initialize order
        @order = order
      end

      # Generates the invoice line parameters Adyen requires in order to process
      # invoice type payments.
      # For more information see: https://docs.adyen.com/developers/open-invoice-manual
      #
      # @return [Hash] Hash containing the invoice lines for the order
      def request_params
        params = {
          openinvoicedata: {
            number_of_lines: @order.line_items.count,
            refund_description: "Refund for #{@order.number}"
          }
        }

        @order.line_items.each_with_index do |item, index|
          params[:openinvoicedata]["line#{index + 1}"] = {
            currency_code: item.currency,
            description: line_item_name(item),
            item_amount: pre_tax_amount_from_line_item(item),
            item_vat_amount: vat_amount_from_line_item(item),
            item_vat_percentage: vat_percent_from_line_item(item),
            line_reference: index + 1,
            number_of_items: item.quantity,
            vat_category: "High"
          }
        end

        params
      end

      private

      # Generate the name to display on the invoice for a given line item. Since
      # the name should uniquely identify it, this includes the option value
      # names for the case where we have the two of the same item with
      # different options.
      #
      # @params [Spree::LineItem] line_item the item to generate a name for
      # @return [String] the name to display on the invoice for the line item
      def line_item_name line_item
        option_values_text = line_item.variant.option_values.map(&:presentation).join(" ")
        [line_item.product.name, option_values_text].join(" ")
      end

      # Compute the pre-tax amount for a single unit within a line item.
      # Since the pre-tax amount and the included tax amount must always add up
      # to the total, we round this down and the included tax amount up. This
      # is the same way Solidus rounds and should avoid rounding errors.
      #
      # @param [Spree::LineItem] line_item the line item to compute the amount for
      # @return [Fixnum] The pre-tax amount in cents
      def pre_tax_amount_from_line_item line_item
        amount = (line_item.discounted_amount - line_item.included_tax_total) / line_item.quantity

        Spree::Money.new(
          BigDecimal.new(amount.to_s).round(2, BigDecimal::ROUND_HALF_DOWN),
          currency: line_item.currency
        ).cents
      end

      # Compute the total VAT percentage applied to the line item by summing all
      # the included tax adjustments applied to it.
      # Adyen requires the VAT percentage in "minor units"
      # ie: 19% VAT => 1900
      #
      # @param [Spree::LineItem] line_item the line item to compute the VAT % for
      # @return [Fixnum] the VAT % in minor units
      def vat_percent_from_line_item line_item
        (sum_of_tax_rates(line_item) * FRACTION_TO_MINOR_UNITS).to_i
      end

      # Compute the VAT amount for a single unit within a line item.
      # We store included_tax_total per line item, which may have quantity > 1
      # and using that value may result in off-by-one errors
      #
      # @param [Spree::LineItem] line_item the line item to compute the VAT amount for
      # @return [Fixnum] the VAT amount for a single unit in cents
      def vat_amount_from_line_item line_item
        amount = line_item.included_tax_total / line_item.quantity

        Spree::Money.new(
          BigDecimal.new(amount.to_s).round(2, BigDecimal::ROUND_HALF_UP),
          currency: line_item.currency
        ).cents
      end

      # Gets the VAT adjustments for the given line item
      #
      # @return [Array<Spree::Adjustment>] The VAT adjustment
      def sum_of_tax_rates line_item
        line_item.adjustments.tax.
          joins("INNER JOIN spree_tax_rates ON spree_tax_rates.id = spree_adjustments.source_id").
          where(spree_tax_rates: { included_in_price: true }).
          map(&:source).
          sum(&:amount)
      end

      def round_to_two_places(amount)
        BigDecimal.new(amount.to_s).round(2, BigDecimal::ROUND_HALF_UP)
      end
    end
  end
end
