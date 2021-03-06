class PopulateCaptchaBackground < ActiveRecord::Migration
	def self.up
		CaptchaBackground.create(:fname=>'Bg-LtBlue_bricks-large-light.gif')
		CaptchaBackground.create(:fname=>'Bg-LtBlue_glass-wall.gif')
		CaptchaBackground.create(:fname=>'Bg-LtBlue_bricks-large-medium.gif')
		CaptchaBackground.create(:fname=>'Bg-LtBlue_diagonal-reverse.gif')
		CaptchaBackground.create(:fname=>'Bg-LtBlue_lines.gif')
		CaptchaBackground.create(:fname=>'Bg-LtBlue_diamonds.gif')
		CaptchaBackground.create(:fname=>'Bg-LtBlue_grass.gif')
		CaptchaBackground.create(:fname=>'Bg-LtBlue_metal-panel.gif')
		CaptchaBackground.create(:fname=>'Bg-LtBlue_bricks-medium.gif')
		CaptchaBackground.create(:fname=>'Bg-LtBlue_crackle.gif')
		CaptchaBackground.create(:fname=>'Bg-LtBlue_letters.gif')
		CaptchaBackground.create(:fname=>'Bg-LtBlue_diagonal-light.gif')
		CaptchaBackground.create(:fname=>'Bg-LtBlue_crackle-white.gif')
		CaptchaBackground.create(:fname=>'Bg-LtBlue_mosaic.gif')
		CaptchaBackground.create(:fname=>'Bg-LtBlue_diagonal.gif')
		CaptchaBackground.create(:fname=>'Bg-LtBlue_diamonds-light.gif')
		CaptchaBackground.create(:fname=>'Bg-LtBlue_bricks-light.gif')
		CaptchaBackground.create(:fname=>'Bg-LtBlue_ceramic-tile.gif')
	end

	def self.down
		CaptchaBackground.destroy_all
	end
end
