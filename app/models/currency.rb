class Currency < ApplicationRecord
  include ActionView::Helpers::TagHelper

  def disp_name
    acron = description
    acron += ": 1 #{name} = #{xchange} USD" unless xchange.nil?
    content_tag(:acronym, name, title: name)
  end

  def self.names_map
    all.map { |currency| [currency.name, currency.id] }.to_h
  end
end
