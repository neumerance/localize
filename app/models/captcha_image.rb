class CaptchaImage < ApplicationRecord
  has_attachment storage: :file_system, max_size: 100.kilobytes, content_type: :image, file_system_path: "#{PHOTO_PATH}/#{table_name}/#{Rails.env}", par: true, partition: false
  validates_as_attachment
  validates_uniqueness_of :user_rand, scope: 'client_id', allow_nil: true

  CHARS_TO_USE = 'ABCDEFGHJKLNPRTXYZ23456789'.freeze
  CODE_LENGTH = 4

  IMG_SIZE = [150, 40].freeze

  def generate_image(user_rand = nil, client_id = nil)
    # create the random code
    txt = ''
    (0...CODE_LENGTH).each do
      ch_idx = rand(CHARS_TO_USE.length)
      txt += CHARS_TO_USE[ch_idx..ch_idx]
    end

    background_id = rand(CaptchaBackground.count) + 1
    captcha_background = CaptchaBackground.find(background_id)
    image = Magick::Image.read(captcha_background.image_fname)[0]

    image.resize!(IMG_SIZE[0], IMG_SIZE[1])
    mark = Magick::Image.new(IMG_SIZE[0], IMG_SIZE[1]) { self.background_color = 'white' }

    gc = Magick::Draw.new
    gc.gravity = Magick::CenterGravity
    gc.pointsize = 20
    gc.font_family = 'Ariel' # 'Sans' # "Courier"
    gc.font_weight = Magick::NormalWeight
    gc.stroke = '#8080c0' # 'black'
    gc.annotate(mark, 0, 0, 0, 0, txt)

    # mark = mark.shade(true, 310, 40)
    image.composite!(mark, Magick::CenterGravity, Magick::DarkenCompositeOp)

    self.width = image.columns
    self.height = image.rows
    self.size = image.try(:filesize).try(:>, 0) ? image.filesize : 1
    self.create_time = Time.now
    self.user_rand = user_rand
    self.client_id = client_id

    logger.info "------ image.columns:#{image.columns}, image.rows:#{image.rows}, image.filesize:#{image.filesize}"

    # remember the code
    self.code = txt
    ok = save
    if ok
      # save the image
      FileUtils.mkdir_p(File.dirname(full_filename))
      image.write(full_filename)
    end

    # image.destroy!
    # GC.start

    ok

  end

  def destroy
    was_path = full_filename
    super
    begin
      FileUtils.rmdir(File.dirname(was_path))
    rescue
    end
  end

end
