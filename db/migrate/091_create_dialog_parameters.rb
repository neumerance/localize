class CreateDialogParameters < ActiveRecord::Migration
	def self.up
		create_table( :dialog_parameters, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :web_dialog_id, :int
			t.column :name, :string
			t.column :value, :string
		end
	end

	def self.down
		drop_table :dialog_parameters
	end
end
