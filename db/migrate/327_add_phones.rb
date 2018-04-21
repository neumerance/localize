class AddPhones < ActiveRecord::Migration
	def self.up
		Phone.create(:name => "iPhone")
		Phone.create(:name => "iPad")
		Phone.create(:name => "Android")
		Phone.create(:name => "Blackberry")
		Phone.create(:name => "Symbian")
		Phone.create(:name => "Windows Mobile")
	end
end
