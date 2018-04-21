class ProblemDeposit < ApplicationRecord
  belongs_to :invoice

  CREATED = 1
  RESOLVED = 2

end
