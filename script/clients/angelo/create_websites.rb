require 'csv'

fname = 'script/clients/angelo/sites.txt'
f = File.open(fname)
txt = f.read
f.close

client_email = 'info@splashpress.com'
translator_emails = ['ayamamoto300@yahoo.com', 'baguio.konomi@gmail.com']
password = 'hybr1d'

client = User.where('email=?', client_email).first
translators = translator_emails.collect { |e| User.where('email=?', e).first }

en = Language.where('name=?', 'English').first
ja = Language.where('name=?', 'Japanese').first

amount = 0.03
cur = DEFAULT_CURRENCY_ID

created_websites = []

cnt = 0
CSV::Reader.parse(txt) do |row|
  if cnt >= 1
    url = 'http://' + row[0]
    name = row[0].tr('.', '_')
    description = "Blog about #{row[1]}"
    puts "#{url} -> #{name}. Description: #{description}"

    website = Website.new(url: url, name: name, platform_kind: WEBSITE_WORDPRESS, description: description, login: 'admin', password: password, blogid: 1, pickup_type: 0)
    website.client = client
    website.save!

    offer = WebsiteTranslationOffer.new(from_language_id: en.id, to_language_id: ja.id, amount: amount, currency_id: cur, url: url, login: 'admin', password: password, blogid: 1)
    offer.website = website
    offer.save!

    translators.each do |translator|
      contract = WebsiteTranslationContract.new(status: TRANSLATION_CONTRACT_ACCEPTED)
      contract.website_translation_offer = offer
      contract.translator = translator
      contract.save!
    end

    created_websites << website

  end
  cnt += 1
end
