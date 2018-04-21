class Option < ApplicationRecord
  def self.get(name, init_value)
    res = find_by(name: name)
    res = create!(name: name, value: init_value) unless res
    res
  end
end
