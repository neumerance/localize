# Helper class for fast icl support,

if ENV['CONSOLE_HELPERS'] || Rails.const_defined?('Console')
  puts '
    ___ ____            _                    _ _
   |_ _/ ___|__ _ _ __ | |    ___   ___ __ _| (_)_______
    | | |   / _` |  _ \| |   / _ \ / __/ _` | | |_  / _ \
    | | |__| (_| | | | | |__| (_) | (_| (_| | | |/ /  __/
   |___\____\__,_|_| |_|_____\___/ \___\__,_|_|_/___\___|
                                                         '.red
  puts '         - Welcome to the supporter console -'.blue
  puts "\r\n\r\n"

  puts "Oh dear, doing support? Let me help you...\r\n"
  puts "history | history(search) to navigate previous console commands\r\n"
  puts 'you can use shortcuts to quickly search. for example:'
  puts '   > c 5             ' + '# Will return the CmsRequest with id 5'.white
  puts '   > u arnoldroa     ' + '# Will search an User by id / email / nickname'.white
  puts ''
  puts 'After search if you call the shortcut without param it will return the last result:'
  puts ''
  puts '   > c 5'
  puts '   > c ' + '# Will be the CmsRequest#5 found in the previous command'.white
  puts ''
  puts ' Full list of shortcuts'

  module SuperSupporter
    ALIAS = {
      t: TextResource,
      rs: ResourceString,
      st: StringTranslation,
      rc: ResourceChat,

      p: Project,
      r: Revision,
      # Commented due to error: undefined method `has_attachment'
      # at the moment of loading this file 'attachment_fu' is not loaded yet
      # v: Version,
      ch: Chat,
      b: Bid,

      w: Website,
      c: CmsRequest,

      m: MoneyAccount,

      mw: ManagedWork,

      u: User
    }.freeze

    ALIAS.each do |shortcode, klass|
      puts "   #{shortcode.to_s.yellow}: #{klass}"

      define_method(shortcode) do |*args|
        id = args.first
        var = eval "$#{shortcode}"
        return var if id.nil?
        puts "Searching for #{klass}: #{id}"
        var = klass[id]
        eval "$#{shortcode} = var"
      end

      define_method("#{shortcode}=") do |_value|
        puts 'Warning: You are assigning a value to a ICL console reserved word'.yellow
        eval "$#{shortcode} = value"
      end
    end

    def history(grep = nil)
      h = Readline::HISTORY.to_a
      if grep
        h.select { |x| x.include? grep.to_s }
      else
        h
      end
    end

    def login(locator)
      user = User[locator]
      return 'Not able to find the user' unless user

      user.login_info
    end
  end

  def vim(file)
    system "vim #{file}"
  end

  # ActiveRecord helpers
  class ActiveRecord::Base
    def self.[](id)
      find id
    end

    alias ua update_attribute
  end

  include SuperSupporter
end
