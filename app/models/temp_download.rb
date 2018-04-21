class TempDownload < ApplicationRecord
  belongs_to :user

  def accesskey
    Digest::MD5.hexdigest(id.to_s + 'sdfs0df98lkj3')
  end
end
