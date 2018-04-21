class AddInvoiceToCmsRequest < ActiveRecord::Migration[5.0]
  def change
    add_reference :cms_requests, :invoice, foreign_key: true
  end
end
