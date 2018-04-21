class AddManagedWorkToProjects < ActiveRecord::Migration
	def self.up
		RevisionLanguage.all.each do |rl|
			if !rl.managed_work
				selected_bid = rl.selected_bid
				translation_status = (selected_bid && BID_WAITING_FOR_REVIEW_STATUS.include?(selected_bid.status)) ? MANAGED_WORK_WAITING_FOR_REVIEWER : MANAGED_WORK_CREATED
				managed_work = ManagedWork.new(	:active=>MANAGED_WORK_INACTIVE,
												:translation_status=>translation_status,
												:from_language_id=>rl.revision.language_id,
												:to_language_id=>rl.language_id)
				if rl.revision.project.client
					managed_work.translator = rl.revision.project.client.reviewer(rl.revision.language_id,id)
				end
				managed_work.client = rl.revision.project.client
				managed_work.owner = rl
				managed_work.notified = 0
				managed_work.save!
			end
		end
	end

	def self.down
	end
end
