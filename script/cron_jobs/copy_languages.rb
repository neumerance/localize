require 'sqlite3'

puts 'started'
db_path = File.expand_path("#{Rails.root}/cgi-bin/sqlite-db/#{Rails.env}/languages.db")
db = SQLite3::Database.new(db_path)
puts db_path

#  clean the old tables from the sqlite database
db.execute('DROP TABLE IF EXISTS languages;')
db.execute('DROP TABLE IF EXISTS language_costs;')

# create the languages table in the sqlite database
# db.execute( "select * from test" )
db.execute('CREATE TABLE languages (id INT AUTO_INCREMENT UNIQUE, name VARCHAR(40), major INT);')
db.execute('CREATE TABLE language_costs (id INT AUTO_INCREMENT UNIQUE, from_id INT, to_id INT, cost_in_cents INT);')

languages = Language.all

lang_cost = 13

idx = 1
languages.each do |lang|
  db.execute("INSERT INTO languages (id,name, major) VALUES (#{lang.id}, '#{lang.name}', #{lang.major});")
  languages.each do |lang_to|
    db.execute("INSERT INTO language_costs (id,from_id, to_id, cost_in_cents) VALUES (#{idx}, #{lang.id}, #{lang_to.id}, #{lang_cost});")
    idx += 1
  end
end
