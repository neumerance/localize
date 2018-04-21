class CreateTranslatorLanguages < ActiveRecord::Migration
  def self.up
    create_table(:translator_languages, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
      t.column :type, :string
      t.column :translator_id, :int
      t.column :language_id, :int
	  t.column :status, :int, :default => 0
	  t.column :description, :text	# the translator needs to tell how he knows this language
    end
  end

  def self.down
    drop_table :translator_languages
  end
end
