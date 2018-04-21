# As Suporter model uses on_vacation method this migration was throwing an error
# when executed. Temporally create vacations table to fix it

class AddTestData < ActiveRecord::Migration
	def self.up
		create_table(:vacations) do |t|
			t.column :user_id, :int
			t.column :beginning, :datetime
			t.column :ending, :datetime
		end

		# ----- acounts -----
		Root.create( :email=>'root@icanlocalize.com' )

		staffamir = Supporter.create(:fname => 'amir',
			:lname => 'helzer',
			:nickname => 'Staff Amir',
			:email => 'support@icanlocalize.com',
			:password => Digest::MD5.hexdigest(Time.now.to_s),
			:userstatus => USER_STATUS_REGISTERED)

		if (Rails.env=='development') || (Rails.env=='sandbox')
			
			orit = Translator.create(:fname => 'orit',
				:lname => 'helzer',
				:nickname => 'Orit',
				:email => 'orit@onthegosoft.com',
				:password => Digest::MD5.hexdigest(Time.now.to_s),
				:userstatus => USER_STATUS_REGISTERED)

			amir = Client.create(:fname => 'amir',
				:lname => 'helzer',
				:nickname => 'Amir',
				:email => 'amir.helzer@onthegosoft.com',
				:password => Digest::MD5.hexdigest(Time.now.to_s),
				:userstatus => USER_STATUS_REGISTERED)

			bruce_sup = Supporter.create(:fname => 'bruce',
				:lname => 'pearson',
				:nickname => 'Bruce CL',
				:email => 'bruce@blazertech.net',
				:password => Digest::MD5.hexdigest(Time.now.to_s),
				:userstatus => USER_STATUS_REGISTERED)

			client10 = Client.create(:fname => 'client',
				:lname => '10',
				:nickname => 'client10',
				:email => 'client10@hotmail.com',
				:password => Digest::MD5.hexdigest(Time.now.to_s),
				:userstatus => USER_STATUS_REGISTERED)

			guy = Translator.create(:fname => 'important',
				:lname => 'guy',
				:nickname => 'Guy',
				:email => 'guy@hotmail.com',
				:password => Digest::MD5.hexdigest(Time.now.to_s),
				:userstatus => USER_STATUS_REGISTERED)
		end
		
		# ----- languages -----
		Language.create(:name => 'English', :major=>1)
		Language.create(:name => 'Spanish', :major=>1)
		Language.create(:name => 'German', :major=>1)
		Language.create(:name => 'French', :major=>1)

		# ----- currencies -----
		usd = Currency.create(:name => 'USD',
			:description => 'United states dollar',
			:paypal_identifier => 'USD',
			:xchange => nil)

		Currency.create(:name => 'Euro',
			:description => 'European Union currency',
			:paypal_identifier => 'EUR',
			:xchange => 1.2)

		# ----- categories -----
		File.open("#{Rails.root}/script/categories/cat_list.txt","r") do |f|
			f.readlines().each do |line|
				Category.create(:name => line.strip,
					:description => '')
			end
		end
		
		if (Rails.env=='development') || (Rails.env=='sandbox')
			# ----- user accounts -----
			UserAccount.create(:owner_id => amir.id,
				:balance => 100000,
				:currency_id => usd.id)

			UserAccount.create(:owner_id => client10.id,
				:balance => 100000,
				:currency_id => usd.id)
			
			ExternalAccount.create(:owner_id => amir.id,
														:external_account_type => EXTERNAL_ACCOUNT_PAYPAL,
														:status => PAYPAL_VERIFIED_EMAIL_STATUS,
														:identifier => 'orit_1184012536_per@onthegosoft.com')
		end
	end

	def self.down
	end
end
