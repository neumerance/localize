class UserDownload < ApplicationRecord
  belongs_to :user
  belongs_to :download
end
