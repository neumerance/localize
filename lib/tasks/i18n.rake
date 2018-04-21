namespace :i18n do
  desc 'Create mo-files for L10n'
  task :makemo do
    require 'gettext/utils'
    require 'locale'
    GetText.create_mofiles(true, 'po', 'locale')
  end

  desc 'Update pot/po files to match new version.'
  task :updatepo do
    $LOAD_PATH << 'vendor/gems/locale-2.0.5/lib'
    require 'gettext/utils'
    require 'locale'
    MY_APP_TEXT_DOMAIN = 'icanlocalize'.freeze
    MY_APP_VERSION     = 'icanlocalize 0.1.0'.freeze
    GetText.update_pofiles(MY_APP_TEXT_DOMAIN,
                           Dir.glob('{app/controllers,app/views,app/helpers,lib}/**/*.{rb,rhtml,erb}') + ['app/models/reminder.rb', 'app/models/reminder_mailer.rb', 'app/models/cms_request.rb', 'app/models/cms_target_language.rb', 'app/models/website_translation_contract.rb', 'app/models/website_translation_offer.rb', 'app/models/website.rb', 'app/models/invoice.rb'],
                           MY_APP_VERSION)
  end
end
