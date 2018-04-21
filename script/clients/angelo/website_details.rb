require 'csv'

client_email = 'info@splashpress.com'
client = User.where('email=?', client_email).first

fname = 'script/clients/angelo/sites.txt'
f = File.open(fname)
txt = f.read
f.close

cnt = 0
CSV::Reader.parse(txt) do |row|
  if cnt >= 1
    url = 'http://' + row[0]
    name = row[0].tr('.', '_')
    description = "Blog about #{row[1]}"
    website = client.websites.where('(url=?) AND (name=?) AND (description=?)', url, name, description).first
    puts "#{website.id},#{website.accesskey}"
  end
  cnt += 1
end
