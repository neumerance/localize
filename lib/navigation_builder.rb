class NavigationBuilder
  attr_reader :controller, :action, :id
  attr_accessor :navigation

  def initialize(controller, action, id, user)
    @controller = controller
    @action     = action
    @id         = id
    @user       = user
    @navigation = []
  end

  def build_navigation
    case @user[:type]
    when 'Client'
      client_navigation
    when 'Translator'
      translator_navigation
    when 'Supporter', 'Admin'
      admin_supporter_navigation
    when 'Alias'
      alias_navigation
    else
      self.navigation = [[false, %w(Logout login logout)]]
    end

    top    = []
    bottom = []

    navigation.each do |top_bar|
      top << [top_bar[0], top_bar[1]]
      next unless top_bar[0]
      next unless top_bar.length > 2
      top_bar[2].each do |bottom_bar|
        bottom << [bottom_bar[0], bottom_bar[1]]
      end
    end

    [top, bottom]
  end

  def highlight_translation_projects?
    (controller == 'client' && action == 'index') ||
      %w(
        arbitrations
        bids
        chats
        cms_requests
        issues shortcodes
        projects
        resource_chats
        resource_downloads
        resource_strings
        resource_strings
        resource_translations
        resource_uploads
        revisions
        text_resources
        web_messages
        website_translation_contracts
        website_translation_offers
        websites
      ).include?(controller)
  end

  def highlight_bidding_projects?
    %w(
      bids
      chats
      projects
      revisions
    ).include?(controller)
  end

  def highlight_software_localization?
    %w(
      resource_chats
      resource_downloads
      resource_strings
      resource_translations
      resource_uploads
      text_resources
    ).include?(controller)
  end

  def highlight_cms_translation?
    %w(
      cms_requests
      shortcodes
      website_translation_contracts
      website_translation_offers
      websites
    ).include?(controller)
  end

  def highlight_my_profile?
    ((controller == 'users') && !(action == 'show' && id != @user.id)) ||
      ((controller == 'users') && (action == 'show') && (id == @user.id)) ||
      ((controller == 'client') && action.starts_with?('getting_started') || (action == 'translate_with_ta')) ||
      %w(
        finance
        reminders
        notifications
        private_translators
        vacations
        managed_works
      ).include?(controller)
  end

  def highlight_getting_started?
    controller == 'client' && action.starts_with?('getting_started')
  end

  def highlight_user_profile?
    controller == 'users' && action == 'show' && id == @user.id
  end

  def highlight_manage_alias?
    controller == 'users' && action == 'manage_alias' && id == @user.id
  end

  def highlight_search?
    controller == 'search' ||
      (controller == 'users' && action == 'show' && id != @user.id) ||
      controller == 'bookmarks'
  end

  def highlight_translators_search?
    controller == 'search' && (action == 'translators' || action == 'by_language')
  end

  def client_navigation
    self.navigation = [[
      highlight_translation_projects?, [_('Translation Projects'), '/client'],
      [
        [highlight_cms_translation?, [_('WPML website translation'), '/wpml/websites']],
        [highlight_bidding_projects?, [_('Bidding projects'), '/projects']],
        [controller == '/web_messages', [_('Instant translation projects'), '/web_messages']],
        [highlight_software_localization?, [_('Software localization'), '/text_resources']],
        [controller == '/arbitrations', [_('Arbitrations'), '/arbitrations']],
        [controller == '/issues', [_('Tracked issues'), '/issues']]
      ]
    ]]

    self.navigation += [[
      highlight_my_profile?, [_('Control Panel'), '/users', 'my_profile'],
      [
        [highlight_getting_started?,                   [_('Getting started'), '/client', 'getting_started']],
        [highlight_user_profile?,                      [_('Profile'), '/users', 'show', @user.id]],
        [controller == '/notifications',                [_('Notification preferences'), '/notifications']],
        [controller == '/finance' && action == 'index', [_('Deposits and payments'), '/finance']],
        [controller == '/private_translators',          [_('Private translators'), '/private_translators']],
        [controller == '/reminders',                    [_('Reminders'), '/reminders']],
        [highlight_manage_alias?, [_('Manage Aliases'), "/users/#{@user.id}/manage_aliases"]]
      ]
    ]]

    self.navigation += [[
      (controller == '/tus'), [_('Translation Memory'), '/tus', 'index', { user_id: @user.id }],
      [
        [(action == 'index'), [_('Browse'), '/glossary_terms', 'index', { user_id: @user.id }]]
      ]
    ]]

    if (@user.display_options & DISPLAY_GLOSSARY) != 0
      self.navigation += [[
        (controller == '/glossary_terms'), [_('Glossary'), '/glossary_terms', 'index', { user_id: @user.id }],
        [
          [(action == 'index'), [_('Browse'), '/glossary_terms', 'index', { user_id: @user.id }]],
          [(action == 'new_import'), [_('Import'), '/glossary_terms', 'new_import', { user_id: @user.id }]]
        ]
      ]]
    end

    if (@user.display_options & DISPLAY_SEARCH) != 0
      self.navigation += [[
        highlight_search?, [_('Search'), '/search'],
        [
          [(controller == '/search') && (action == 'index'), [_('Projects'), '/search']],
          [(controller == '/search') && (action == 'cms'), ['Website jobs', '/search', 'cms']],
          [highlight_translators_search?, [_('Translators'), '/search', 'translators']],
          [(controller == '/bookmarks'), [_('Bookmarks'), '/bookmarks']]
        ]
      ]]
    end

    if (@user.display_options & DISPLAY_AFFILIATE) != 0
      self.navigation += [[
        controller == '/my', [_('Affiliate'), '/my'],
        [
          [(controller == '/my') && (action == 'index'), [_('Overview'), '/my', 'index']],
          [(controller == '/my') && (action == 'edit'), [_('Edit invitation'), '/my', 'edit']],
          [(controller == '/my') && (action == 'report'), [_('Report'), '/my', 'report']]
        ]
      ]]
    end

    self.navigation += [[
      (controller == '/support'), [_('Get Help'), '/support'],
      [
        [action == 'tickets_summary', [_('Your support tickets'), '/support', 'tickets_summary']],
        [action == 'new', [_('Create a new ticket'), '/support', 'new']]
      ]
    ]]
  end

  def highlight_projects_translators?
    %w(
      projects
      revisions
      chats
      bids
      arbitrations
      translator
      web_messages
      website_translation_contracts
      cms_requests
      text_resources
      resource_chats
      resource_strings
      issues
      website_translation_off
    ).include?(controller)
  end

  def highlight_my_account_for_translator?
    (controller == 'users' && !(action == 'show' && id != @user.id)) ||
      %w(
        finance
        reminders
        notifications
        private_translators
        vacations
        managed_works
      ).include?(controller)
  end

  def highlight_profile_for_translator?
    ((controller == 'users') && (action == 'show') && (id == @user.id))
  end

  def highlight_search_for_translator?
    controller == 'search' ||
      (controller == 'users' && action == 'show' && id != @user.id) ||
      controller == 'bookmarks'
  end

  def translator_navigation
    self.navigation = [
      [
        highlight_projects_translators?, %w(Projects translator),
        [
          [(controller == 'translator') && (action == 'open_work'), ['Open work', 'translator', 'open_work']],
          [(controller == 'translator') && (action == 'projects_in_progress'), ['Projects in progress', 'translator', 'projects_in_progress']],
          [(controller == 'translator') && (action == 'active_bids'), ['Projects you bid on', 'translator', 'active_bids']],
          [(controller == 'translator') && (action == 'completed_projects'), ['Completed projects', 'translator', 'completed_projects']],
          [(controller == 'translator') && (action == 'website_translation_contracts'), ['CMS translation', 'translator', 'website_translation_contracts']],
          [controller == 'web_messages', ['Instant Translation projects', 'web_messages']],
          [(controller == 'arbitrations'), %w(Arbitrations arbitrations)],
          [(controller == 'issues'), ['Tracked issues', 'issues']]
        ]
      ],
      [
        highlight_my_account_for_translator?, ['My Account', 'users', 'my_profile'],
        [
          [highlight_profile_for_translator?, ['Profile', 'users', 'show', @user.id]],
          [controller == 'notifications', ['Notification preferences', 'notifications']],
          [controller == 'finance' && (action == 'index'), ['Payments and withdrawals', 'finance']],
          [controller == 'private_translators', ['Private clients', 'private_translators', 'clients']],
          [controller == 'users' && (action == 'managed_works'), ['Managed projects', 'users', 'managed_works', @user.id]],
          [controller == 'reminders', %w(Reminders reminders)]
        ]
      ],
      [
        highlight_search_for_translator?, %w(Search search),
        [
          [(controller == 'search') && (action == 'index'), ['Projects and users', 'search']],
          [highlight_translators_search?, %w(Translators search translators)],
          [(controller == 'search') && (action == 'new_projects'), ['New projects', 'search', 'new_projects']],
          [(controller == 'search') && (action == 'cms'), ['Website jobs', 'search', 'cms']],
          [(controller == 'bookmarks'), %w(Bookmarks bookmarks)]
        ]
      ],
      [
        controller == 'my', %w(Affiliate my),
        [
          [(controller == 'my') && (action == 'index'), %w(Overview my index)],
          [(controller == 'my') && (action == 'edit'), ['Edit invitation', 'my', 'edit']],
          [(controller == 'my') && (action == 'report'), %w(Report my report)]
        ]
      ],
      [
        (controller == 'support'), %w(Support support),
        [
          [(action == 'tickets_summary'), ['Your support tickets', 'support', 'tickets_summary']],
          [(action == 'new'), ['Create a new ticket', 'support', 'new']]
        ]
      ]
    ]
  end

  def highlight_supporter_home_tasks?
    (
      controller == 'supporter' &&
      !%w(projects web_messages).include?(action) &&
      action != 'cms_projects' &&
      action != 'anon_projects' &&
      action != 'web_supports' &&
      action != 'text_resources'
    ) ||
      (controller == 'site_notices') ||
      (controller == 'resource_formats')
  end

  def highlight_projects_supporter_projects?
    (
      %w(projects revisions chats bids supporter).include?(controller) &&
      %w(projects cms_projects text_resources anon_projects web_supports web_messages).include?(action)
    ) || controller == 'shortcodes'
  end

  def admin_supporter_navigation
    home_tasks = [
      [(action == 'manage_fixed_rates'), ['Manage fixed rates', 'supporter', 'manage_fixed_rates']],
      [(action == 'manage_website_project_auto_assign'), ['Manage website project auto-assign', 'supporter', 'manage_website_project_auto_assign']],
      [(action == 'auto_assigned_website_projects'), ['Auto-assigned website projects', 'supporter', 'auto_assigned_website_projects']],
      [(action == 'pending_payments_report'), ['Website pending payments', 'supporter', 'pending_payments_report']],
      [(action == 'language_verifications'), ['Language verifications', 'supporter', 'language_verifications']],
      [(action == 'identity_verifications'), ['Identity verifications', 'supporter', 'identity_verifications']]
    ]

    if @user[:type] == 'Admin'
      home_tasks << [action == 'tasks',                ['Scheduled tasks', 'supporter', 'tasks']]
      home_tasks << [controller == 'site_notices',     ['Site notices', 'site_notices', 'index']]
      home_tasks << [controller == 'resource_formats', ['Resource formats', 'resource_formats', 'index']]
      home_tasks << [action == 'incomplete_requests',  ['Incomplete CMS documents', 'supporter', 'incomplete_requests']]
      home_tasks << [action == 'cms_requests',         ['Recent CMS documents', 'supporter', 'cms_requests']]
      home_tasks << [action == 'flags',                ['Flagged projects', 'supporter', 'flags']]
      home_tasks << [action == 'new_website_quote',    ['Website quote', 'supporter', 'new_website_quote']]
      home_tasks << [action == 'unfinished_translation_jobs', ['Unfinished translation', 'supporter', 'unfinished_translation_jobs']]
      home_tasks << [action == 'unstarted_auto_assignment_jobs', ['Unstarted auto assignment jobs', 'supporter', 'unstarted_auto_assignment_jobs']]
    end

    self.navigation << [highlight_supporter_home_tasks?, ['My home', 'supporter'], home_tasks]

    self.navigation += [
      [
        (controller == 'support'), %w(Tickets support supporter_index),
        [
          [(action == 'supporter_index'), ['Awaiting response', 'support', 'supporter_index']],
          [(action == 'supporter_browse'), %w(Assigned support supporter_browse)]
        ]
      ],
      [
        (controller == 'arbitrations'), %w(Arbitrations arbitrations supporter_index),
        [
          [(action == 'supporter_index'), ['Under your responsibility', 'arbitrations', 'supporter_index']],
          [(action == 'pending'), %w(Pending arbitrations pending)]
        ]
      ],
      [
        highlight_projects_supporter_projects?, %w(Projects supporter projects),
        [
          [(controller == 'projects'),   %w(Bidding projects index)],
          [(action == 'cms_projects'),   ['CMS projects', 'supporter', 'cms_projects']],
          [(action == 'text_resources'), ['Software localization', 'supporter', 'text_resources']],
          [(action == 'anon_projects'),  ['CMS Projects by anonymous users', 'supporter', 'anon_projects']],
          [(action == 'web_messages'),   ['Instant Translation', 'supporter', 'web_messages']],
          [(controller == 'shortcodes'), ['Website Block Shortcodes (Global)', 'shortcodes', 'index']]
        ]
      ],
      [
        (controller == 'users'), %w(Users users),
        [
          [(action == 'index'),                      ['All users', 'users', 'index']],
          [(action == 'find'),                       %w(Find users find)],
          [(action == 'list_translation_languages'), ['Find by language', 'users', 'list_translation_languages']],
          [(action == 'bilinguals'),                 ['Show all bilinguals', 'users', 'bilinguals']],
          [(action == 'top'),                        ['Top clients', 'users', 'top']],
          [(action == 'clients_by_source'),          ['Clients by Source', 'users', 'clients_by_source']],
          [(action == 'top'),                        %w(Admins users admins)]
        ]
      ]
    ]

    if @user[:type] == 'Admin'
      self.navigation += [
        [
          %w(admin_finance finance vouchers money_transactions).include?(controller), %w(Financials admin_finance),
          [
            [((controller == 'admin_finance') && (action == 'index')), %w(Summary admin_finance index)],
            [(action == 'invoice_search'), %w(Invoices admin_finance invoice_search)],
            [((controller == 'money_transactions') && (action == 'index')), ['All transactions', 'money_transactions', 'index']],
            [(action == 'history'), ['Fee transactions', 'admin_finance', 'history']],
            [(action == 'payments'), ['Mass payments', 'admin_finance', 'payments']],
            [(action == 'external_transactions'), ['External transactions', 'admin_finance', 'external_transactions']],
            [(action == 'paypal_transactions'), ['PayPal transactions', 'admin_finance', 'paypal_transactions']],
            [(action == 'countries_taxes'), ['Countries Taxes', 'admin_finance', 'countries_taxes']],
            [(action == 'revenue_report'), ['Revenue Report', 'admin_finance', 'revenue_report']],
            [(controller == 'vouchers'), %w(Vouchers vouchers index)]
          ]
        ],
        [
          (controller == 'newsletters'), %w(Newsletters newsletters),
          [
            [(action == 'index'), %w(Browse newsletters index)],
            [(action == 'new'), %w(New newsletters new)]
          ]
        ],
        [(controller == 'downloads'), %w(Downloads downloads)],
        [
          (controller == 'reports'), %w(Reports reports),
          [
            [(action == 'index'), ['Generate Reports', 'reports', 'index']],
            [(action == 'eu_vat_transactions'), ['EU VAT Transactions', 'reports', 'eu_vat_transactions']],
            [(action == 'eu_vat_by_state'), ['EU VAT By State', 'reports', 'eu_vat_by_state']],
            [(action == 'website_projects'), ['Website Projects', 'reports', 'website_projects']],
            [(action == 'monthly_ta_projects'), ['TA Projects', 'reports', 'monthly_ta_projects']],
            [(action == 'clients_projects'), ["Client's Projects", 'reports', 'clients_projects']],
            [(action == 'review_usage'), ['Review Usage', 'reports', 'review_usage']],
            [(action == 'automatic_translator_assignment_usage'), ['Automatic Translator Assignment Usage', 'reports', 'automatic_translator_assignment_usage']]
          ]
        ],
        [
          (controller == 'destinations'), %w(Destinations destinations),
          [
            [(controller == 'destinations') && (action == 'index'), ['Browse destinations', 'destinations', 'index']],
            [(controller == 'destinations') && (action == 'new'),   ['New destinations', 'destinations', 'new']]
          ]
        ],
        [
          (controller == 'help_topics') || (controller == 'help_placements') || (controller == 'help_groups'), ['Help Tips', 'help_topics'],
          [
            [(controller == 'help_topics'), ['Help topics', 'help_topics', 'index']],
            [(controller == 'help_groups'), ['Help groups', 'help_groups', 'index']],
            [(controller == 'help_placements'), ['Help placements', 'help_placements', 'index']]
          ]
        ]
      ]
    end

    self.navigation += [[
      (controller == 'error_reports' || controller == 'user_clicks'), ['Error reports', 'error_reports'],
      [
        [(controller == 'error_reports'), ['TAS Reports', 'error_reports']],
        [(controller == 'user_clicks'),   ['Website Errors', 'user_clicks']]
      ]
    ]]
  end

  def alias_navigation
    self.navigation = [
      [controller == 'client', [_('Translation Projects'), 'client']]
    ]

    if @user.can_view_finance?
      self.navigation << [controller == 'finance' && action == 'index', [_('Deposits and payments'), 'finance']]
    end

    self.navigation += [[
      controller == 'support', [_('Get Help'), 'support'],
      [
        [action == 'tickets_summary', [_('Your support tickets'), 'support', 'tickets_summary']],
        [action == 'new', [_('Create a new ticket'), 'support', 'new']]
      ]
    ]]
  end
end
