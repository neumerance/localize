class FixTranslationStatusForStrings < ActiveRecord::Migration
	def self.up
	
		need_review_cnt = 0
		dont_need_review_cnt = 0
	
		# find all the strings which have REVIEW_PENDING_ALREADY_FUNDED status, but don't need review and change back to REVIEW_NOT_NEEDED
		ResourceLanguage.includes(:text_resource).all.each do |rl|
			# check if it is not being reviewed
			if (rl.managed_work && (rl.managed_work.active == MANAGED_WORK_ACTIVE))
				rl.text_resource.string_translations.where('(string_translations.language_id=?) AND (string_translations.pay_reviewer=?) AND (string_translations.review_status=?)', rl.language.id,1,REVIEW_NOT_NEEDED).each do |st|
					st.update_attributes(:review_status=>REVIEW_AFTER_TRANSLATION)
					need_review_cnt += 1
				end
			else
				rl.text_resource.string_translations.where('(string_translations.language_id=?) AND (string_translations.pay_reviewer=?) AND (string_translations.review_status=?)', rl.language_id, 1, REVIEW_PENDING_ALREADY_FUNDED).each do |st|
					st.update_attributes(:review_status=>REVIEW_NOT_NEEDED)
					dont_need_review_cnt += 1
				end
			end
		end
			
		puts "Changed #{need_review_cnt} strings to need review and #{dont_need_review_cnt} to not need review"
		
	end

	def self.down
	end
end
