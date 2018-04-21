class PopulateGoogleLanguages < ActiveRecord::Migration
	LANGUAGE_CODES = { 'Arabic'=>'ar',
			'Bulgarian'=>'bg',
			'Chinese (Simplified)'=>'zh-CN',
			'Chinese (Traditional)'=>'zh-TW',
			'Croatian'=>'hr',
			'Czech'=>'cs',
			'Danish'=>'da',
			'Dutch'=>'nl',
			'English'=>'en',
			'Finnish'=>'fi',
			'French'=>'fr',
			'German'=>'de',
			'Greek'=>'el',
			'Hindi'=>'hi',
			'Italian'=>'it',
			'Japanese'=>'ja',
			'Korean'=>'ko',
			'Norwegian'=>'no',
			'Polish'=>'pl',
			'Portuguese'=>'pt',
			'Romanian'=>'ro',
			'Russian'=>'ru',
			'Spanish'=>'es',
			'Swedish'=>'sv'}
			
	def self.up
			
		LANGUAGE_CODES.each do |name,code|
			language = Language.where(name: name).first
			if language
				gl = GoogleLanguage.create!(:language_id=>language.id, :code=>code)
			end
		end
			
	end
  
	def self.down
		LANGUAGE_CODES.each do |name,code|
			language = Language.where(name: name).first
			if language && language.google_language
				language.google_language.destroy
			end
		end
	end
end
