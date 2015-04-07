require 'grape'

GIFT_CARD_BALANCES = Hash.new { |hash, key| hash[key] = 0 }
GIFT_CARD_BALANCES.merge! '1' => 10_000,
                          '2' => 10,
                          '3' => 0

##
# Validates that a gift card number exists
class ExistingGiftCardNumber < Grape::Validations::Base
  def validate_param!(attr_name, params)
    return if GIFT_CARD_BALANCES.key?(params[attr_name])
    fail Grape::Exceptions::Validation,
         params: [@scope.full_name(attr_name)],
         message: 'must be an existing gift card number'
  end
end

##
# Validates that a gift card's current value is sufficient to capture the given amount
class AvailableBalanceSufficient < Grape::Validations::Base
  def validate_param!(attr_name, params)
    return if GIFT_CARD_BALANCES[params[:number]] >= params[attr_name].to_f
    fail Grape::Exceptions::Validation,
         params: [@scope.full_name(attr_name)],
         message: 'must be less than or equal to the current balance'
  end
end

##
# Example implementation of Springboard Retail custom payment webhooks.
#
# Note this uses an in-memory hash instead of a real database as an example.
class App < Grape::API
  version 'v1', using: :header, vendor: 'springboardretail'
  format :json

  helpers do
    def update_balance(number, amount)
      new_balance = GIFT_CARD_BALANCES[number] += amount
      status 200
      { balance: new_balance }
    end
  end

  resource :gift_cards do
    desc "Returns a gift card's current balance"
    params do
      requires :number, existing_gift_card_number: true
    end
    post :check_balance do
      if GIFT_CARD_BALANCES.key?(params[:number])
        status 200
        { balance: GIFT_CARD_BALANCES[params[:number]] }
      else
        error!({ message: "Gift card not found: #{params[:number]}" }, 404)
      end
    end

    desc 'Capture payment from a gift card'
    params do
      requires :number, existing_gift_card_number: true
      requires :amount, type: Float, available_balance_sufficient: true
    end
    post :capture do
      update_balance(params[:number], -params[:amount])
    end

    desc 'Refund payment to a gift card'
    params do
      requires :number
      requires :amount, type: Float
    end
    post :refund do
      update_balance(params[:number], params[:amount])
    end
  end
end
