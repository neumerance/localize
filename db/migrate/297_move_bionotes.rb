class MoveBionotes < ActiveRecord::Migration
	def self.up
		User.where('bio is NOT NULL').each do |user|
			bionote = Bionote.new(:body=>user.bio)
			bionote.owner = user
			bionote.chgtime = Time.now
			bionote.save!
		end
	end

	def self.down
		Bionote.all.each do |bionote|
			bionote.owner.bio = bionote.body
			bionote.owner.save
		end
	end
end
