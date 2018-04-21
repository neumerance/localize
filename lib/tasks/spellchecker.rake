require 'open3'

namespace :spellchecker do
  desc 'This is will install all spellchecker dictionaries'
  task install: :environment do
    puts '==== THIS WILL TAKE LONG HAVE PATIENCE ===='
    Open3.popen3('sudo apt-get install aspell') do |_stdin, stdout, _stderr|
      puts stdout.read
    end

    languages = %w(af ak sq am ar hy az eu be bn bs br bg ca cop co hr cs da nl dyu en eo et fo fj fi fr fy fur ff gl lg de el gn gu ht ha he hil hi hu is ig id ia ga it jv kn csb km rw ky kg ku la lv li ln lt nds lb mk mg ms ml mt gv mi mr mn mos nv ng ne nd nso nb nn ny oc or fa pl pt pa qu ro rn ru sm sg sc gd sr sn sk sl so nr st es su sw ss sv tl ty tg ta te tet ti to ts tn tr tk uk hsb ur uz ve vi wa cy wo xh yi yo zu)
    languages.each do |lang|
      Open3.popen3("sudo apt-get install aspell-#{lang}") do |_stdin, stdout, _stderr|
        puts stdout.read
      end
    end
  end

end
