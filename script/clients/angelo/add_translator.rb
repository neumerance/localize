require 'csv'

fname = 'script/clients/angelo/sites.txt'
f = File.open(fname)
txt = f.read
f.close

client_email = 'info@splashpress.com'
translator_emails = ['ayamamoto300@yahoo.com', 'baguio.konomi@gmail.com', 'doiseiki@gmail.com', 'keikoeire@yahoo.co.jp', 'email@yui.jeez.jp', 'akirakin@gmail.com', 'languages.az@gmail.com', 'peter@translator-world.com']
password = 'hybr1d'

client = User.where('email=?', client_email).first
translators = translator_emails.collect { |e| User.where('email=?', e).first }

en = Language.where('name=?', 'English').first
ja = Language.where('name=?', 'Japanese').first

cnt = 0
done = 0

CSV::Reader.parse(txt) do |row|
  if cnt >= 1
    url = 'http://' + row[0]
    name = row[0].tr('.', '_')
    description = "Blog about #{row[1]}"
    puts "#{url} -> #{name}. Description: #{description}"

    # website = client.websites.where('(url=?) AND (description=?) AND (name=?)',url,description,name).first
    website = client.websites.where('(url=?)', url).first

    if !website
      puts "\n\n---> website doesn't exist: #{name} / #{url}\n\n"
    else

      offer = website.website_translation_offers.where('(from_language_id=?) AND (to_language_id=?)', en.id, ja.id).first

      translators.each do |translator|
        next unless translator
        contract = offer.website_translation_contracts.where('translator_id=?', translator.id).first
        next if contract
        contract = WebsiteTranslationContract.new(status: TRANSLATION_CONTRACT_ACCEPTED)
        contract.website_translation_offer = offer
        contract.translator = translator
        contract.save!
        puts "Creating contract for translator: #{translator.full_name}"
        done += 1
      end

    end

  end
  cnt += 1
end

puts "created #{done} entries"
