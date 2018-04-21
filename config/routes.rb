Rails.application.routes.draw do
  get 'hello_world', to: 'hello_world#index'
  # mount Browserlog::Engine => '/logs'

  resources :vouchers

  resources :downloads do
    collection do
      get :get
    end

    member do
      get :show_recent
    end
  end

  resources :shortcodes do
    member do
      put :toggle_enabled
    end
  end

  resources :money_transactions
  resources :destinations do
    collection do
      get :go
    end

    member do
      get :visits
    end
  end

  resources :help_topics
  resources :help_groups
  resources :help_placements

  resources :feedbacks do
    collection do
      get :list
    end
  end

  resources :error_reports do
    member do
      get :resolution
    end
  end

  resources :users do
    collection do
      get :signup
      post :find_results
      get :list_translation_languages
      post :update_name_and_email
      post :update_translation_language_results
      post :update_display_settings
      get :translation_analytics_welcome
      post :update_password
      get :find
      get :clients
      get :top
      get :my_profile
      get :bilinguals
      get :clients_by_source
      get :translators
      get :request_practice_project
      get :admins
      get :supporters
      post :setup_practice_project
      get :complete_sandbox
      get :remove_compact_display_session
    end

    member do
      post :update_rate
      patch :update_autoassignment
      post :do_verification_deposit
      post :add_from_languages
      get :reset_password
      post :edit_categories
      post :edit_personal_details
      get :validate
      post :invite_to_job
      post :request_external_account_validation
      post :add_to_languages
      get :managed_works
      post :edit_resume
      get :manage_aliases
      post :resend_activation_email
      get :validate_external_account
      post :del_language
      post :update_public
      post :edit_translation_availability
      post :update_tool
      post :edit_affiliate
      post :add_verification_document
      post :add_language_document
      post :toggle_admin_notifications
      post :edit_image
      get :verification
      post :update_tool_others
      post :del_verification_document
      post :del_language_document
      get :resend_confirmation_email
      post :update_bio
      get :manage_works
      get :translator_languages
      post :close_account
      post :edit_language
      post :update_supporter_data
      get :web_messages_list
      post :validate_user_vat
    end

    resources :translators do
      member do
        patch :update_autoassignment
      end
    end

    resources :user_clicks
    resources :vacations

    resources :glossary_terms do
      collection do
        post :csv_export
        post :import
        get :ta_glossary_edit
        get :new_import
        get :new_tmx_import
        post :tmx_import
        post :show_glossary
      end

      member do
        post :edit_translation
        post :locate
      end
    end

    resources :tus do
      collection do
        get :search
      end
    end

    resources :language_managers do
      resources :language_manager_applications do
        member do
          post :update_application_status
          post :create_message
          get :attachment
        end
      end
    end
  end

  resources :bookmarks

  resources :newsletters do
    collection do
      get :feed
      get :sitemap
    end
    member do
      get :plain
      get :count_users
      put :test
    end
  end

  resources :advertisements
  resources :leads do
    collection do
      post :import
    end
  end

  resources :reminders do
    collection do
      get :hide
      get :unhide
      post :delete_selected
    end
  end

  resources :arbitrations do
    collection do
      get :supporter_index
      post :request_cancel_bid
      post :create_cancel_bid_arbitration
      get :pending
      get :summary
    end

    member do
      post :assign_to_supporter
      post :edit_ruling
      post :ask_for_supporter
      post :edit_offer
      post :close
      post :create_message
      post :delete_offer
      post :accept_offer
    end
  end

  resources :projects do
    collection do
      get :lookup_by_private_key
      get :new_sisulizer
      get :searcher
      get :continue_sisulizer
      post :create_sisulizer
      get :summary
    end

    member do
      get :can_create_new_revisions
    end

    resources :support_files

    resources :revisions do
      collection do
        post :lookup_by_private_key
      end

      member do
        post :transfer_payment_for_translation
        post :edit_name
        post :pay_bids_with_paypal
        post :edit_categories
        get :invite_translator
        post :edit_conditions
        post :pay_bids_with_transfer
        get :support_file
        post :edit_languages
        post :add_required_amount_for_auto_accept
        post :reuse_translators
        post :edit_source_language
        get :select_private_translators
        post :edit_file_upload
        post :edit_project_description
        post :review_payment_for_private_translators
        post :edit_description
        post :edit_release_status
        post :update_supporter_data
        get :support_files
      end

      resources :versions do
        member do
          post :duplicate_complete
        end
      end

      resources :chats do
        collection do
          post :send_broadcast
        end

        member do
          post :check_invoice_status
          post :delete_bid
          post :finalize_review
          post :transfer_bid_payment
          post :reopen
          post :refuse_bid
          post :enable_review
          post :finalize_bids
          post :cancel_bid
          post :pay_for_review
          put :update_bid
          post :declare_done
          post :create_message
          post :cancel_review
          post :edit_bid
          post :open_bid_to_edit
          post :accept_bid
          get :attachment
          post :set_access
          post :save_bid
          post :review_complete
          post :finalize_bid
        end

        resources :bids do
          collection do
            post :unset_all_bids
          end

          member do
            post :unset_bid
          end
        end
      end
    end
  end

  resources :websites do
    collection do
      post :ts_quote
      get :new_user
      get :cms_requests
      get :searcher
      get :translators
      post :create_by_cms
      get :validate_affiliate
    end

    member do
      get :search_cms
      get :request_transfer_account
      get :custom_text
      post :close_all
      post :transfer_account
      get :flush_requests
      get :explain
      get :create_language_pair
      get :quote
      post :add_counts
      get :web_messages_for_pickup
      post :reuse_translators
      get :get
      post :create_explanation
      post :store
      get :translator_chat
      post :swap_translators
      post :ack_message_pickup
      post :create_message
      get :new_ticket
      get :language_pair
      post :edit_tm_use
      post :update_by_cms
      post :migrate
      post :edit_description
      post :update_supporter_data
      post :create_ticket
      get :links
      post :confirm_resignation
      post :confirmed_resignation
      get :cancel_resignation
      post :reveal_wp_credentials
      get :all_comm_errors
    end

    resources :shortcodes do
      member do
        put :toggle_enabled
      end
    end

    resources :translation_snapshots do
      collection do
        post :create_by_cms
      end
    end

    resources :website_translation_offers do
      collection do
        get :enter_password
        get :load_or_create_from_ta
      end

      member do
        get :review
        get :report
        post :cancel_invitations
        get :enter_details
        post :update_details
        post :resend_notifications
        post :update_site_status
        get :new_invitation
        get :auto_setup
        post :edit_description
        post :create_invitation
        get :resign_from_website
      end

      resources :website_translation_contracts do
        member do
          post :update_application_status
          post :create_message
          get :attachment
        end
      end
    end

    match '/websites/:website_id/website_translation_contracts/send_broadcast' => 'website_translation_contracts#send_broadcast', :as => :website_translation_contracts_broadcast, via: [:post]

    resources :cms_requests do
      collection do
        get :report
        get :count_requests_to_pickup
        get :cms_id
        post :update_cms_id
        post :multiple_retry
        post :cancel_multiple_translations
      end

      member do
        post :retry
        get :cms_upload
        get :get_html_output
        post :notify_tas_done
        post :store_output
        post :enable_review
        post :report_error
        post :close_all_errors
        get :chat
        post :reset
        get :cms_download
        post :cancel_translation
        post :resend
        post :redo
        post :update_status
        post :debug_complete
        post :create_message
        get :xliff
        post :update_permlink
        post :release
        post :deliver
        post :assign_to_me
        post :notify_cms_delivery
        get :download
        post :update_languages
        post :toggle_tmt_config
        post :toggle_force_ta
      end

      resources :comm_errors
    end

    resources :cms_terms do
      resources :cms_term_translations
    end
  end

  match 'wpml-websites/:id.:format' => 'websites#show', :via => :get

  resources :web_messages do
    collection do
      get :review_index
      get :searcher
      get :fetch_next
      post :pre_create
      post :select_to_languages
    end

    member do
      get :review
      get :translation
      post :final_review
      post :hold_for_translation
      post :correct
      post :hold_for_review
      post :flag_as_complex
      post :create_message
      get :release_from_hold
      post :release_from_hold
      post :update_remaining_time
      get :attachment
      post :unassign_translator
      post :review_complete
    end
  end

  resources :private_translators do
    collection do
      get :clients
    end
  end

  match 'text_resources/quote_for_resource_translation' => 'text_resources#quote_for_resource_translation', via: [:get, :post]
  resources :text_resources do
    collection do
      get :searcher
      get :target_languages
    end

    member do
      post :apply_from_other_projects
      post :add_from_owner
      post :import_xml
      get :browse
      post :edit_resource_account
      post :invite_to_job
      post :return_to_owner
      post :cleanup_master_strings
      post :edit_media
      get :comment_strings
      post :reset_string_contexts
      post :clear_notifications
      post :edit_languages
      post :update_word_counts
      post :update_language_status
      get :get
      post :add_po_translation
      post :reuse_translators
      post :delete_strings_with_no_context
      get :new_existing_translation
      post :delete_untranslated
      post :deposit_payment
      post :abort_purge_strings
      get :translation_summary
      post :edit_tm_use
      post :find_in_other_projects
      post :create_translations
      get :edit_description
      get :export_xml
      get :export_csv
      post :edit_output_name
      post :update_supporter_data
      post :create_testimonial
    end

    resources :resource_uploads do
      member do
        post :scan_resource
        get :download_translations
        post :apply_to_context
      end
    end

    resources :resource_translations do
      member do
        post :scan_resource
      end
    end

    resources :resource_downloads do
      member do
        get :download_mo
        get :download
      end
    end

    resources :resource_chats do
      collection do
        post :send_broadcast
        post :start_translations
      end

      member do
        post :start_review
        post :translation_complete
        post :update_application_status
        post :create_message
        get :attachment
        post :review_complete
      end
    end

    resources :resource_languages do
      member do
        post :unassign_translator
      end
    end

    resources :resource_strings do
      collection do
        post :delete_selected
        get :find_mismatching
        get :size_report
        post :convert_selected
        post :add_auto_comments
        post :set_display_instructions
        post :update_version_num
      end

      member do
        post :edit_length_limit
        post :update_translation
        post :complete_review
        post :edit_translation
        post :change_label
        post :edit_comment
        post :remove_master
      end
    end
  end

  resources :resource_languages do
    collection do
      post :mass_unassign
    end
  end

  resources :site_notices
  resources :resource_formats

  resources :managed_works do
    collection do
      post :bulk_assign_reviewer
    end

    member do
      post :resign_reviewer
      post :be_reviewer
      post :remove_translator
      post :set_translator
      post :update_status
      post :unassign_reviewer
      post :create_message
      post :enable
      post :assign_reviewer
      get :attachment
      post :disable
    end
  end

  resources :issues do
    collection do
      get :issues_i_created
      get :issues_for_me
      get :project
    end

    member do
      post :update_status
      post :create_message
      get :attachment
      get :subscribe
    end
  end

  resources :translators do
    collection do
      get :search
    end
  end

  resources :translation_analytics_profiles do
    member do
      post :test_emails
    end
  end

  resources :translation_analytics_language_pairs do
    collection do
      get :edit_rates
      post :change_rates
      get :edit_deadlines
      post :change_deadlines
    end
  end

  resources :translation_analytics do
    collection do
      post :dismiss_alert_setup
      get :deadline_table
      get :overview
      get :deadlines
      get :progress_graph
      get :details
    end
  end

  resources :alias_profiles do
    collection do
      post :create_alias
    end

    member do
      get :edit_financial
      post :update_projects
      post :update_financial
      post :update_password
      post :alias_table_line
      get :edit_password
      post :destroy_alias
      get :edit_projects
    end
  end

  resources :alert_emails do
    member do
      post :update_enabled
    end
  end

  resources :string_translations do
    member do
      post :force_review
    end
  end

  resources :keyword_projects do
    collection do
      post :collection_create
      post :free_sample
      get :show_keywords
      get :example_doc
      get :instructions
    end

    member do
      post :save_progress
      get :translate
      get :download
      post :release_money
    end
  end

  resources :companies do
    collection do
      get :new_language
    end
  end

  # Namespace for the new UI for WPML clients, as described in icldev-2008
  namespace :wpml do
    resources :registrations, only: [:new, :create]
    resources :sessions, only: [:new]
    resources :websites, only: [:index, :show, :update] do
      member do
        get :token
        post :migrated
        post :edit_website_inplace
        post :edit_tm_inplace
        post :toggle_review
        post :assign_reviewer
        get :client_can_pay_any_language_pairs
        post :create_testimonial
      end
      collection do
        get :api_token
      end
      resources :translation_jobs do
        member do
          post :toggle_review
        end
        collection do
          get :invite_translator
        end
      end
      resources :payments, only: [:new, :create] do
        member do
          get :paypal_complete
        end
      end
    end
  end

  namespace :supporter do
    resources :pending_payments_report, controller: '/wpml/pending_payments_report', only: [:index]
  end

  namespace :api, defaults: { format: 'json' } do
    scope module: :v1, constraints: ApiConstraints.new(version: 1, default: true) do
      namespace :email do
        resources :bounces, only: :create
      end

      post 'authenticate', to: 'api#authenticate'
      post 'quote', to: 'api#quote'

      resources :jobs, only: [:index, :show] do
        member do
          post :save
          post :complete
          get :preview
        end
        resources :webta_issues, only: [:index] do
          member do
            post :close_issue
            post :create_issue_message
          end
          collection do
            get :get_by_mrk
            post :create_issue_by_mrk
          end
        end
      end
      resources :its, only: [:index, :show] do
        member do
          post :save
          post :take
          post :release
        end
      end
      resources :issues, only: [:create, :show]
      resources :glossaries, only: [:index, :create, :update]
    end
  end

  resources :language_pair_fixed_prices do
    member do
      get :language_price_details_translators
      get :update_field
    end
  end

  resources :client, only: [:index] do
    collection do
      get :sandbox_jobs
    end
  end

  match '/delayed_job' => DelayedJobWeb, :anchor => false, :via => [:get, :post]

  get '/finance/invoice/:id', to: 'finance#invoice', format: [:html, :pdf]
  # post '/api/authenticate', to: 'api#authenticate'

  # match 'company/new_language' => 'company#new_language', via: [:get]
  # match ':controller/service.wsdl' => '#wsdl', via: [:get]
  get '/supporter/manage_fixed_rates/:id/details', to: 'supporter#language_price_details', format: [:html], as: :fixed_price_details
  delete '/supporter/delete_web_messages', to: 'supporter#batch_delete_web_messages', as: :batch_delete_web_messages
  # to make rails mailer preview work
  match '/rails/mailers/:path', via: :get, to: 'rails/mailers#preview', constraints: { path: /[\/\w]+/ }

  match '/:controller(/:action(/:id))(.:format)', via: [:get, :post, :put, :delete]

  get '*unmatched_route', to: 'application#route_not_found'
  post '*unmatched_route', to: 'application#route_not_found'
  put '*unmatched_route', to: 'application#route_not_found'
end
