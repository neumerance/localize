class Country < ApplicationRecord
  def self.get_list
    [['----', 0]] + Country.all.order('name ASC').collect { |country| [country.name, country.id] }
  end

  def nname
    _(name)
  end

  def belongs_to_tax_group?(tax_group)
    tax_group == self.tax_group
  end

  def requiring_tax?
    self.tax_group == 'EU'
  end

  def self.require_vat_list
    Country.where(tax_group: 'EU').pluck(:id)
  end
end
