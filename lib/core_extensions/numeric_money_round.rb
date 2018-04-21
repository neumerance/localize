Numeric.class_eval do
  # @ToDo IMPORTANT MONEY CALCULATION ISSUE
  # @ToDo Refactor software to use this method
  # This method is defined in multiple places, it was originally wrote using
  # ceil instead of floor, which reound the number to the higger value,
  # but paypal seems to round to floor. Due of this sometime the paypal_ipn
  # callback sometimes doesnt match the value of the invoices.
  # Is possible that we only want to FLOOR for tax calculation, and for other
  # values use ceil
  def round_money
    rounded = (self * 100).ceil / 100.0
    # Ensure correct precision
    BigDecimal(rounded.to_s)
  end
  # A developer may look for "def ceil_money", this comment allows him to find it
  alias_method :ceil_money, :round_money

  def floor_money
    rounded = (self * 100).floor / 100.0
    # Ensure correct precision
    BigDecimal(rounded.to_s)
  end
end
