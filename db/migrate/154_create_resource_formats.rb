class CreateResourceFormats < ActiveRecord::Migration
	def self.up
		create_table( :resource_formats, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :name, :string
			t.column :description, :string
			
			t.column :label_delimiter, :string
			t.column :text_delimiter, :string
			t.column :separator_char, :string
			t.column :multiline_char, :string
			t.column :end_of_line, :string
			t.column :comment_char, :string
			t.column :encoding, :int
			t.column :line_break, :int

			t.timestamps
		end
	end

	def self.down
		drop_table :resource_formats
	end
end
