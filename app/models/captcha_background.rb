class CaptchaBackground < ApplicationRecord
  CAPTCHA_BACKGROUND_PATH = File.join(Rails.root, '/captcha_background').freeze

  def image_fname
    File.join(CAPTCHA_BACKGROUND_PATH, fname)
  end
end
