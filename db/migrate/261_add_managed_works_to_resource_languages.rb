class AddManagedWorksToResourceLanguages < ActiveRecord::Migration
	def self.up
		cnt = 0
		ResourceLanguage.all.each do |rl|
			if rl.text_resource && rl.text_resource.client && !rl.managed_work
				translation_status = ((rl.text_resource.resource_strings.count > 0) && !rl.text_resource.string_translations.where('(string_translations.language_id=?) AND (status=?)',rl.language_id,STRING_TRANSLATION_BEING_TRANSLATED).first) ? MANAGED_WORK_WAITING_FOR_REVIEWER : MANAGED_WORK_CREATED
				managed_work = ManagedWork.new(	:active=>MANAGED_WORK_INACTIVE,
												:translation_status=>translation_status,
												:from_language_id=>rl.text_resource.language_id,
												:to_language_id=>rl.language_id)
				managed_work.client = rl.text_resource.client
				managed_work.translator = rl.text_resource.client.reviewer(rl.text_resource.language_id,rl.language_id)
				managed_work.owner = rl
				managed_work.notified = 0
				managed_work.save!
				
				cnt += 1
			end
		end
		
		puts "Added #{cnt} managed works."
	end

	def self.down
	end
end
