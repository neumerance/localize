# config/initializers/fast_gettext.rb
FastGettext.add_text_domain 'icanlocalize', path: 'po', type: :po, report_warning: false
FastGettext.default_available_locales = ['en']
FastGettext.default_text_domain = 'icanlocalize'
