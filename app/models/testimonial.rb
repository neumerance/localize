class Testimonial < ApplicationRecord
  belongs_to :owner, polymorphic: true
end
