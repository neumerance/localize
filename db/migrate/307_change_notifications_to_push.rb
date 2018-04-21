class ChangeNotificationsToPush < ActiveRecord::Migration

	PAGE = 10

	def self.up
	
		hour_ago = Time.now-1.hour
		
		add_index :sent_notifications, [:user_id], :name=>'user', :unique => false
		
		add_column :web_messages, :notified, :integer, :default=>1
		add_index :web_messages, [:notified], :name=>'notified', :unique => false
		
		add_column :website_translation_offers, :notified, :integer, :default=>1
		add_index :website_translation_offers, [:notified], :name=>'notified', :unique => false

		add_column :resource_languages, :notified, :integer, :default=>1
		add_index :resource_languages, [:notified], :name=>'notified', :unique => false
		
		add_column :revisions, :notified, :integer, :default=>1
		add_index :revisions, [:notified], :name=>'notified', :unique => false
		
		add_column :managed_works, :notified, :integer, :default=>1
		add_index :managed_works, [:notified], :name=>'notified', :unique => false

		add_column :cms_requests, :notified, :integer, :default=>1
		add_index :cms_requests, [:notified], :name=>'notified', :unique => false

		cnt = WebMessage.where('create_time > ?',hour_ago).count
		idx = 0
		while (idx < cnt)
			puts "setting notified for - WebMessage - #{idx} / #{cnt}"
			WebMessage.transaction do
				WebMessage.where('create_time > ?',hour_ago).offset(idx).limit(PAGE).each do |object|
					object.update_attributes(:notified=>0)
				end
			end
			idx += PAGE
		end
		
		cnt = WebsiteTranslationOffer.where('updated_at > ?',hour_ago).count
		idx = 0
		while (idx < cnt)
			puts "setting notified for - WebsiteTranslationOffer - #{idx} / #{cnt}"
			WebsiteTranslationOffer.transaction do
				WebsiteTranslationOffer.where('updated_at > ?',hour_ago).each do |object|
					object.update_attributes(:notified=>0)
				end
			end
			idx += PAGE
		end
			
		cnt = ResourceLanguage.where('updated_at > ?',hour_ago).count
		idx = 0
		while (idx < cnt)
			puts "setting notified for - ResourceLanguage - #{idx} / #{cnt}"
			ResourceLanguage.transaction do
				ResourceLanguage.where('updated_at > ?',hour_ago).each do |object|
					object.update_attributes(:notified=>0)
				end
			end
			idx += PAGE
		end
				
		cnt = Revision.where('creation_time > ?',hour_ago).count
		idx = 0
		while (idx < cnt)
			puts "setting notified for - Revision - #{idx} / #{cnt}"
			Revision.transaction do
				Revision.where('creation_time > ?',hour_ago).each do |object|
					object.update_attributes(:notified=>0)
				end
			end
			idx += PAGE
		end
				
		cnt = ManagedWork.where('updated_at > ?',hour_ago).count
		idx = 0
		while (idx < cnt)
			puts "setting notified for - ManagedWork - #{idx} / #{cnt}"
			ManagedWork.transaction do
				ManagedWork.where('updated_at > ?',hour_ago).each do |object|
					object.update_attributes(:notified=>0)
				end
			end
			idx += PAGE
		end
		
		cnt = CmsRequest.where('updated_at > ?',hour_ago).count
		idx = 0
		while (idx < cnt)
			puts "setting notified for - CmsRequest - #{idx} / #{cnt}"
			CmsRequest.transaction do
				CmsRequest.where('updated_at > ?',hour_ago).each do |object|
					object.update_attributes(:notified=>0)
				end
			end
			idx += PAGE
		end
		
	end

	def self.down
		remove_index :sent_notifications, :name=>'user'
		
		remove_index :web_messages, :name=>'notified'
		remove_column :web_messages, :notified
		
		remove_index :website_translation_offers, :name=>'notified'
		remove_column :website_translation_offers, :notified
		
		remove_index :resource_languages, :name=>'notified'
		remove_column :resource_languages, :notified
		
		remove_index :revisions, :name=>'notified'
		remove_column :revisions, :notified
		
		remove_index :managed_works, :name=>'notified'
		remove_column :managed_works, :notified
		
		remove_index :cms_requests, :name=>'notified'
		remove_column :cms_requests, :notified
	end
end
