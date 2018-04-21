require File.dirname(__FILE__) + '/../test_helper'

class AvailableLanguageTest < ActiveSupport::TestCase
  fixtures :available_languages, :users

  def test_price_for
    available_languages.each do |lp|
      assert_in_delta lp.amount, lp.price_for(:amir), 0.001
      assert_in_delta lp.amount * TOP_CLIENT_DISCOUNT, lp.price_for(:top_client), 0.001
    end
  end
end
