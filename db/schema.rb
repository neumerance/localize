# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20180411114125) do

  create_table "account_lines", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "account_id"
    t.string   "account_type"
    t.datetime "chgtime"
    t.decimal  "balance",              precision: 9, scale: 2, default: "0.0"
    t.integer  "money_transaction_id"
    t.string   "txn_id"
    t.index ["account_type", "account_id", "txn_id"], name: "index_account_lines_on_account_type_and_account_id_and_txn_id", unique: true, using: :btree
    t.index ["account_type", "account_id"], name: "account", using: :btree
    t.index ["chgtime"], name: "by_chgtime", using: :btree
    t.index ["money_transaction_id", "account_id", "account_type"], name: "account_lines_combined", using: :btree
  end

  create_table "active_trail_actions", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4" do |t|
    t.string   "project_type"
    t.integer  "project_id"
    t.integer  "action"
    t.integer  "subject"
    t.datetime "performed_at"
    t.integer  "active_trail_contact_id"
    t.string   "cta_button_link"
    t.index ["project_type", "project_id"], name: "index_active_trail_actions_on_project_type_and_project_id", using: :btree
  end

  create_table "addresses", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer "owner_id"
    t.string  "owner_type"
    t.integer "country_id"
    t.string  "address1"
    t.string  "state"
    t.string  "city"
    t.string  "zip"
  end

  create_table "advertisements", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.string "title"
    t.text   "body",  limit: 65535
  end

  create_table "alert_emails", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "translation_analytics_profile_id"
    t.boolean  "enabled"
    t.string   "name"
    t.string   "email"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "bounced",                          default: false
  end

  create_table "alias_profiles", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer "user_id"
    t.integer "project_access_mode",               default: 0
    t.boolean "project_view",                      default: false
    t.boolean "project_modify",                    default: false
    t.boolean "project_create",                    default: false
    t.text    "project_list",        limit: 65535
    t.text    "website_list",        limit: 65535
    t.text    "text_resource_list",  limit: 65535
    t.text    "web_message_list",    limit: 65535
    t.boolean "financial_view",                    default: false
    t.boolean "financial_deposit",                 default: false
    t.boolean "financial_pay",                     default: false
  end

  create_table "arbitration_offers", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer "arbitration_id"
    t.integer "user_id"
    t.decimal "amount",         precision: 8, scale: 2, default: "0.0"
    t.integer "status"
  end

  create_table "arbitrations", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer "type_code"
    t.integer "object_id"
    t.string  "object_type"
    t.integer "initiator_id"
    t.integer "against_id"
    t.integer "supporter_id"
    t.integer "status"
    t.integer "resolution"
    t.decimal "payment_amount", precision: 8, scale: 2, default: "0.0"
    t.index ["object_id", "object_type"], name: "object", unique: true, using: :btree
  end

  create_table "attachments", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer "message_id"
    t.string  "content_type"
    t.string  "filename"
    t.integer "size"
    t.integer "parent_id"
    t.boolean "backup_on_s3", default: false
    t.index ["backup_on_s3"], name: "backup_on_s3_idx", using: :btree
    t.index ["message_id"], name: "message", using: :btree
  end

  create_table "available_languages", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer "from_language_id"
    t.integer "to_language_id"
    t.integer "qualified"
    t.integer "update_idx"
    t.decimal "amount",           precision: 8, scale: 2, default: "0.07"
  end

  create_table "bids", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "chat_id"
    t.integer  "revision_language_id"
    t.integer  "status"
    t.decimal  "amount",               precision: 8, scale: 2, default: "0.0"
    t.integer  "currency_id"
    t.datetime "accept_time"
    t.datetime "expiration_time"
    t.integer  "lock_version",                                 default: 0
    t.integer  "alert_status",                                 default: 0
    t.integer  "won"
    t.index ["chat_id"], name: "chat", using: :btree
    t.index ["revision_language_id", "won"], name: "bid_won", unique: true, using: :btree
    t.index ["revision_language_id"], name: "revision_language", using: :btree
  end

  create_table "bookmarks", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer "user_id"
    t.integer "resource_id"
    t.string  "resource_type"
    t.text    "note",          limit: 65535
    t.decimal "rating",                      precision: 2, scale: 1, default: "0.0"
  end

  create_table "brandings", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.string  "owner_type"
    t.integer "owner_id"
    t.integer "language_id"
    t.string  "logo_url"
    t.integer "logo_width"
    t.integer "logo_height"
    t.string  "home_url"
    t.index ["owner_type", "owner_id", "language_id"], name: "language_for_owner", unique: true, using: :btree
  end

  create_table "campaing_tracks", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci" do |t|
    t.integer  "campaing_id"
    t.string   "project_type"
    t.integer  "project_id"
    t.integer  "from_language_id"
    t.integer  "to_language_id"
    t.integer  "state"
    t.string   "extra_info"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["campaing_id", "state"], name: "campain_status_index", using: :btree
  end

  create_table "captcha_backgrounds", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.string "fname"
  end

  create_table "captcha_images", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.string   "content_type"
    t.string   "filename"
    t.integer  "size"
    t.integer  "parent_id"
    t.integer  "width"
    t.integer  "height"
    t.datetime "create_time"
    t.string   "code"
    t.integer  "user_rand"
    t.integer  "client_id"
    t.index ["user_rand", "client_id"], name: "client_user_rand", unique: true, using: :btree
  end

  create_table "captcha_keys", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer "client_id"
    t.string  "access_key"
    t.index ["client_id", "access_key"], name: "client_key", unique: true, using: :btree
  end

  create_table "categories", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer "parent_id"
    t.string  "name"
    t.text    "description", limit: 65535
  end

  create_table "cats", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.string "name"
  end

  create_table "cats_users", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer "user_id"
    t.integer "cat_id"
    t.text    "extra",   limit: 65535
  end

  create_table "chats", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer "revision_id"
    t.integer "translator_id"
    t.integer "translator_has_access"
    t.index ["revision_id"], name: "revision", using: :btree
    t.index ["translator_id"], name: "translator", using: :btree
  end

  create_table "client_departments", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer "web_support_id"
    t.integer "language_id"
    t.integer "translation_status_on_create"
    t.string  "name"
    t.index ["web_support_id"], name: "web_support", using: :btree
  end

  create_table "clients_vouchers", id: false, force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer "client_id"
    t.integer "voucher_id"
    t.index ["client_id", "voucher_id"], name: "used_vouchers", unique: true, using: :btree
  end

  create_table "cms_count_groups", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "website_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["website_id", "created_at"], name: "website_by_time", using: :btree
    t.index ["website_id"], name: "website", using: :btree
  end

  create_table "cms_counts", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer "cms_count_group_id"
    t.integer "website_translation_offer_id"
    t.integer "kind"
    t.integer "status"
    t.integer "count"
    t.string  "service"
    t.integer "priority",                     default: 0
    t.string  "code"
    t.string  "translator_name"
    t.index ["cms_count_group_id", "kind"], name: "cms_count_group", using: :btree
    t.index ["website_translation_offer_id", "kind"], name: "website_translation_offer_id", using: :btree
  end

  create_table "cms_request_metas", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "cms_request_id"
    t.string   "name"
    t.string   "value"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["cms_request_id"], name: "cms_request", using: :btree
  end

  create_table "cms_requests", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "website_id"
    t.integer  "status"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "language_id"
    t.string   "title"
    t.string   "permlink"
    t.string   "tas_url"
    t.integer  "tas_port"
    t.string   "list_type"
    t.integer  "list_id"
    t.integer  "last_operation"
    t.integer  "pending_tas",                            default: 0
    t.string   "error_description"
    t.integer  "delivered"
    t.text     "note",                     limit: 65535
    t.string   "idkey"
    t.string   "cms_id"
    t.string   "container"
    t.integer  "notified",                               default: 1
    t.integer  "tp_id"
    t.integer  "word_count"
    t.boolean  "xliff_processed",                        default: false
    t.datetime "deadline"
    t.boolean  "tas_failed",                             default: false
    t.integer  "invoice_id"
    t.integer  "batch_count",                            default: 0
    t.integer  "batch_id"
    t.boolean  "review_enabled"
    t.integer  "blocked_cms_request_id"
    t.boolean  "webta_completed",                        default: false
    t.boolean  "webta_parent_completed",                 default: false
    t.boolean  "ta_tool_parent_completed",               default: false
    t.datetime "completed_at"
    t.index ["blocked_cms_request_id"], name: "index_cms_requests_on_blocked_cms_request_id", using: :btree
    t.index ["idkey"], name: "idkey", using: :btree
    t.index ["invoice_id"], name: "index_cms_requests_on_invoice_id", using: :btree
    t.index ["language_id"], name: "language", using: :btree
    t.index ["notified"], name: "notified", using: :btree
    t.index ["status", "language_id", "website_id"], name: "search", using: :btree
    t.index ["status"], name: "status", using: :btree
    t.index ["website_id", "cms_id"], name: "website_cms_id", using: :btree
    t.index ["website_id", "container"], name: "container", using: :btree
    t.index ["website_id", "list_type", "list_id"], name: "listitems", using: :btree
    t.index ["website_id"], name: "website", using: :btree
  end

  create_table "cms_target_languages", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "cms_request_id"
    t.integer  "language_id"
    t.integer  "status"
    t.integer  "lock_version",     default: 0
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "title"
    t.string   "permlink"
    t.integer  "translator_id"
    t.integer  "delivered"
    t.integer  "word_count"
    t.integer  "money_account_id"
    t.index ["cms_request_id"], name: "cms_request", using: :btree
    t.index ["language_id"], name: "language", using: :btree
    t.index ["status"], name: "status", using: :btree
    t.index ["translator_id"], name: "translator", using: :btree
  end

  create_table "cms_term_translations", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "cms_term_id"
    t.integer  "language_id"
    t.string   "txt"
    t.integer  "status"
    t.integer  "cms_identifier"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["cms_term_id"], name: "parent", using: :btree
  end

  create_table "cms_terms", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "website_id"
    t.integer  "parent_id"
    t.integer  "language_id"
    t.string   "kind"
    t.integer  "cms_identifier"
    t.string   "txt"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["website_id", "kind", "cms_identifier"], name: "cms_id", unique: true, using: :btree
    t.index ["website_id", "parent_id"], name: "children", using: :btree
  end

  create_table "comm_errors", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "cms_request_id"
    t.integer  "status"
    t.integer  "error_code"
    t.string   "error_description"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "error_report",      limit: 65535
    t.index ["cms_request_id"], name: "cms_request", using: :btree
  end

  create_table "contacts", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.string   "email"
    t.string   "fname"
    t.string   "lname"
    t.integer  "department"
    t.string   "subject"
    t.integer  "supporter_id"
    t.integer  "status"
    t.datetime "create_time"
    t.integer  "accesskey"
  end

  create_table "countries", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.string  "code"
    t.string  "name"
    t.integer "language_id"
    t.integer "major"
    t.decimal "tax_rate",              precision: 5, scale: 2
    t.string  "tax_name"
    t.string  "tax_group"
    t.string  "tax_code",    limit: 3
  end

  create_table "currencies", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.string  "name"
    t.string  "description"
    t.string  "paypal_identifier"
    t.decimal "xchange",           precision: 8, scale: 2, default: "0.0"
  end

  create_table "db_content_translations", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer "owner_id"
    t.string  "owner_type"
    t.integer "language_id"
    t.text    "txt",         limit: 65535
  end

  create_table "delayed_jobs", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "priority",                 default: 0
    t.integer  "attempts",                 default: 0
    t.text     "handler",    limit: 65535
    t.text     "last_error", limit: 65535
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string   "locked_by"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "queue"
    t.index ["priority", "run_at"], name: "delayed_jobs_priority", using: :btree
  end

  create_table "destinations", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.string   "url"
    t.integer  "language_id"
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "dialog_parameters", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer "web_dialog_id"
    t.string  "name"
    t.string  "value"
  end

  create_table "documents", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.string   "type"
    t.string   "title"
    t.text     "body",       limit: 65535
    t.string   "encoding"
    t.datetime "chgtime"
    t.integer  "owner_id"
    t.string   "owner_type"
  end

  create_table "downloads", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.string   "content_type"
    t.string   "filename"
    t.integer  "size"
    t.integer  "parent_id"
    t.integer  "width"
    t.integer  "height"
    t.datetime "create_time"
    t.string   "generic_name"
    t.integer  "major_version"
    t.integer  "sub_version"
    t.string   "notes"
    t.string   "usertype"
    t.integer  "os_code",       default: 0
    t.boolean  "backup_on_s3",  default: false
    t.index ["backup_on_s3"], name: "backup_on_s3_idx", using: :btree
  end

  create_table "error_reports", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.string   "email"
    t.integer  "supporter_id"
    t.text     "body",         limit: 65535
    t.string   "description"
    t.datetime "submit_time"
    t.integer  "status"
    t.string   "prog"
    t.string   "version"
    t.string   "os"
    t.string   "digest"
    t.text     "resolution",   limit: 65535
  end

  create_table "external_accounts", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer "owner_id"
    t.integer "external_account_type"
    t.string  "status"
    t.string  "identifier"
    t.integer "address_id"
    t.string  "fname"
    t.string  "lname"
    t.integer "verified",              default: 0
    t.boolean "hidden",                default: false
    t.index ["external_account_type", "identifier"], name: "account_key", unique: true, using: :btree
    t.index ["owner_id"], name: "owner", using: :btree
  end

  create_table "feedbacks", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "owner_id"
    t.string   "owner_type"
    t.text     "txt",              limit: 65535
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "translator_id"
    t.integer  "from_language_id"
    t.integer  "to_language_id"
    t.integer  "rating"
    t.string   "source"
    t.string   "name"
    t.string   "email"
    t.integer  "status",                         default: 0
    t.index ["owner_type", "owner_id"], name: "owner", using: :btree
    t.index ["translator_id"], name: "translator", using: :btree
  end

  create_table "glossary_terms", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "client_id"
    t.integer  "language_id"
    t.string   "txt",         collation: "utf8mb4_general_ci"
    t.string   "description", collation: "utf8mb4_general_ci"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["client_id", "txt", "language_id"], name: "txt", using: :btree
  end

  create_table "glossary_translations", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "glossary_term_id"
    t.integer  "language_id"
    t.string   "txt",              collation: "utf8mb4_general_ci"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "creator_id"
    t.integer  "last_editor_id"
    t.string   "note"
    t.index ["glossary_term_id"], name: "parent", using: :btree
    t.index ["txt", "language_id"], name: "txt", using: :btree
  end

  create_table "google_languages", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer "language_id"
    t.string  "code"
  end

  create_table "help_groups", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.string  "name"
    t.integer "order", default: 0, null: false
  end

  create_table "help_placements", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.string  "controller"
    t.string  "action"
    t.integer "help_group_id"
    t.integer "help_topic_id"
    t.integer "user_match",      default: 0
    t.integer "user_match_mask", default: 0
  end

  create_table "help_topics", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.string  "title"
    t.string  "summary"
    t.string  "url"
    t.integer "display", default: 0, null: false
  end

  create_table "identity_verifications", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "normal_user_id"
    t.string   "verified_item_type"
    t.integer  "verified_item_id"
    t.datetime "chgtime"
    t.integer  "status",             default: 0
  end

  create_table "images", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "owner_id"
    t.string   "owner_type"
    t.integer  "kind"
    t.string   "content_type"
    t.string   "filename"
    t.integer  "size"
    t.integer  "parent_id"
    t.string   "thumbnail"
    t.integer  "width"
    t.integer  "height"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "backup_on_s3", default: false
    t.index ["backup_on_s3"], name: "backup_on_s3_idx", using: :btree
    t.index ["owner_id", "owner_type"], name: "owner", using: :btree
  end

  create_table "invitations", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "normal_user_id"
    t.string   "name"
    t.text     "message",        limit: 65535
    t.integer  "active",                       default: 0
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "invoices", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "kind"
    t.integer  "payment_processor"
    t.integer  "currency_id"
    t.decimal  "gross_amount",      precision: 8, scale: 2, default: "0.0"
    t.decimal  "net_amount",        precision: 8, scale: 2, default: "0.0"
    t.string   "txn"
    t.integer  "status"
    t.datetime "create_time"
    t.datetime "modify_time"
    t.integer  "user_id"
    t.integer  "address_id"
    t.integer  "lock_version",                              default: 0
    t.string   "company"
    t.integer  "subscription_id"
    t.integer  "website_id"
    t.boolean  "demo"
    t.decimal  "tax_amount",        precision: 8, scale: 2, default: "0.0"
    t.decimal  "tax_rate",          precision: 4, scale: 2, default: "0.0", null: false
    t.integer  "tax_country_id"
    t.string   "vat_number"
    t.integer  "source_id"
    t.string   "source_type"
  end

  create_table "issues", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "owner_id"
    t.string   "owner_type"
    t.integer  "initiator_id"
    t.integer  "target_id"
    t.integer  "kind"
    t.integer  "status"
    t.text     "title",           limit: 65535
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "tp_callback_url"
    t.index ["initiator_id"], name: "initiator", using: :btree
    t.index ["owner_type", "owner_id"], name: "owner", using: :btree
    t.index ["target_id"], name: "target", using: :btree
  end

  create_table "keyword_packages", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci" do |t|
    t.integer  "keywords_number",                                       null: false
    t.decimal  "price",                         precision: 8, scale: 2, null: false
    t.text     "comments",        limit: 65535
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "keyword_projects", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci" do |t|
    t.integer  "owner_id",                                  null: false
    t.string   "owner_type",                                null: false
    t.integer  "status",                    default: 0,     null: false
    t.text     "comments",    limit: 65535
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "free_sample",               default: false
  end

  create_table "keyword_translations", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci" do |t|
    t.integer  "keyword_id"
    t.string   "text"
    t.integer  "category"
    t.integer  "hits"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "keywords", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci" do |t|
    t.integer  "purchased_keyword_package_id"
    t.string   "text"
    t.integer  "status",                                     default: 0
    t.text     "result",                       limit: 65535
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "language_pair_fixed_prices", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1" do |t|
    t.integer  "from_language_id"
    t.integer  "to_language_id"
    t.decimal  "calculated_price",                 precision: 8, scale: 2
    t.datetime "created_at",                                                               null: false
    t.datetime "updated_at",                                                               null: false
    t.decimal  "actual_price",                     precision: 8, scale: 2
    t.bigint   "number_of_transactions"
    t.decimal  "calculated_price_last_year",       precision: 8, scale: 2
    t.bigint   "number_of_transactions_last_year"
    t.boolean  "published",                                                default: false
    t.string   "language_pair_id"
    t.index ["from_language_id", "to_language_id"], name: "language_pair", unique: true, using: :btree
    t.index ["from_language_id"], name: "index_language_pair_fixed_prices_on_from_language_id", using: :btree
    t.index ["language_pair_id"], name: "index_language_pair_fixed_prices_on_language_pair_id", unique: true, using: :btree
    t.index ["to_language_id"], name: "index_language_pair_fixed_prices_on_to_language_id", using: :btree
  end

  create_table "languages", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.string  "name"
    t.integer "major",                                           default: 0,       null: false
    t.integer "scanned_for_translators",                         default: 0
    t.integer "rtl",                                             default: 0
    t.string  "iso"
    t.string  "count_method",                                    default: "words"
    t.decimal "ratio",                   precision: 8, scale: 2, default: "1.0"
    t.index ["iso"], name: "iso", unique: true, using: :btree
  end

  create_table "leads", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.string  "name"
    t.string  "url"
    t.string  "description"
    t.string  "contact_title"
    t.string  "contact_fname"
    t.string  "contact_lname"
    t.string  "contact_email"
    t.string  "addr_country"
    t.string  "addr_state"
    t.string  "addr_city"
    t.string  "addr_zip"
    t.string  "addr_street"
    t.string  "phone"
    t.string  "what_they_do"
    t.integer "word_count"
    t.string  "text1"
    t.string  "text2"
    t.string  "text3"
    t.string  "text4"
    t.integer "status",           default: 0
    t.integer "advertisement_id"
    t.integer "contact_id"
    t.integer "user_id"
    t.index ["advertisement_id"], name: "advertisement", using: :btree
    t.index ["user_id"], name: "user", unique: true, using: :btree
  end

  create_table "locks", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.string   "object_type"
    t.string   "object_id"
    t.string   "locked_by"
    t.datetime "lock_time"
    t.index ["object_type", "object_id"], name: "object", unique: true, using: :btree
  end

  create_table "managed_works", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "translator_id"
    t.integer  "owner_id"
    t.string   "owner_type"
    t.integer  "active",             default: 1
    t.integer  "translation_status", default: 0
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "from_language_id"
    t.integer  "to_language_id"
    t.integer  "client_id"
    t.integer  "notified",           default: 1
    t.integer  "review_type"
    t.index ["notified"], name: "notified", using: :btree
    t.index ["owner_type", "owner_id"], name: "owner", using: :btree
    t.index ["translator_id"], name: "translator", using: :btree
  end

  create_table "mass_payment_receipts", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.string   "withdrawal_id"
    t.string   "txn"
    t.decimal  "fee",           precision: 8, scale: 2, default: "0.0"
    t.integer  "status"
    t.datetime "chgtime"
  end

  create_table "message_deliveries", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "message_id"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["message_id"], name: "message", using: :btree
    t.index ["user_id"], name: "user", using: :btree
  end

  create_table "messages", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "owner_id"
    t.string   "owner_type"
    t.integer  "user_id"
    t.text     "body",       limit: 65535
    t.datetime "chgtime"
    t.integer  "is_new",                   default: 1
    t.index ["owner_type", "owner_id"], name: "owner", using: :btree
  end

  create_table "money_accounts", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.string  "type"
    t.decimal "balance",           precision: 9, scale: 2, default: "0.0"
    t.integer "currency_id"
    t.integer "owner_id"
    t.integer "lock_version",                              default: 0
    t.decimal "hold_sum",          precision: 8, scale: 2, default: "0.0"
    t.string  "warning_signature"
    t.index ["type", "owner_id"], name: "owner", using: :btree
  end

  create_table "money_transactions", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.decimal  "amount",               precision: 8, scale: 2, default: "0.0"
    t.decimal  "fee_rate",             precision: 8, scale: 2, default: "0.0"
    t.decimal  "fee",                  precision: 8, scale: 2, default: "0.0"
    t.integer  "currency_id"
    t.string   "source_account_type"
    t.integer  "source_account_id"
    t.string   "target_account_type"
    t.integer  "target_account_id"
    t.integer  "operation_code"
    t.integer  "status"
    t.datetime "chgtime"
    t.string   "owner_type"
    t.integer  "owner_id"
    t.integer  "lock_version",                                 default: 0
    t.integer  "affiliate_account_id"
    t.index ["owner_type", "owner_id"], name: "owner", using: :btree
    t.index ["source_account_type", "source_account_id"], name: "source_account", using: :btree
    t.index ["target_account_type", "target_account_id"], name: "target_account", using: :btree
  end

  create_table "newsletters", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.string   "subject"
    t.text     "body",       limit: 65535
    t.integer  "flags",                    default: 0
    t.datetime "chgtime"
    t.string   "sql_filter"
  end

  create_table "options", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.string   "name"
    t.string   "value"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "parsed_xliffs", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "xliff_id"
    t.integer  "client_id"
    t.integer  "cms_request_id"
    t.integer  "website_id"
    t.integer  "source_language_id"
    t.integer  "target_language_id"
    t.text     "top_content",        limit: 65535
    t.text     "bottom_content",     limit: 65535
    t.text     "header",             limit: 4294967295
    t.datetime "created_at",                                        null: false
    t.datetime "updated_at",                                        null: false
    t.integer  "word_count",                            default: 0
    t.integer  "tm_word_count",                         default: 0
    t.index ["client_id"], name: "client_id", using: :btree
    t.index ["cms_request_id"], name: "index_parsed_xliffs_on_cms_request_id", using: :btree
    t.index ["source_language_id"], name: "source_language_id", using: :btree
    t.index ["target_language_id"], name: "target_language_id", using: :btree
    t.index ["xliff_id"], name: "xliff_id", using: :btree
  end

  create_table "paypal_mock_replies", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.string "txn_id"
    t.string "last_name"
    t.string "receiver_email"
    t.string "payment_status"
    t.string "payment_gross"
    t.string "tax"
    t.string "residence_country"
    t.string "address_state"
    t.string "payer_status"
    t.string "txn_type"
    t.string "address_country"
    t.string "payment_date"
    t.string "first_name"
    t.string "item_name"
    t.string "address_street"
    t.string "address_name"
    t.string "item_number"
    t.string "receiver_id"
    t.string "business"
    t.string "payer_id"
    t.string "address_zip"
    t.string "payment_fee"
    t.string "address_country_code"
    t.string "address_city"
    t.string "address_status"
    t.string "receipt_id"
    t.string "mc_fee"
    t.string "mc_currency"
    t.string "payer_email"
    t.string "payment_type"
    t.string "mc_gross"
    t.string "invoice"
    t.index ["txn_id"], name: "txn_id", unique: true, using: :btree
  end

  create_table "pending_money_transactions", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1" do |t|
    t.integer  "owner_id"
    t.string   "owner_type"
    t.integer  "money_account_id"
    t.decimal  "amount",           precision: 8, scale: 2
    t.datetime "created_at",                               null: false
    t.datetime "updated_at",                               null: false
    t.datetime "deleted_at"
    t.index ["money_account_id"], name: "index_pending_money_transactions_on_money_account_id", using: :btree
    t.index ["owner_id"], name: "index_pending_money_transactions_on_owner_id", using: :btree
  end

  create_table "phones", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.string "name"
  end

  create_table "phones_users", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer "user_id"
    t.integer "phone_id"
    t.text    "extra",    limit: 65535
  end

  create_table "private_translators", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "client_id"
    t.integer  "translator_id"
    t.integer  "status"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "problem_deposits", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer "reason"
    t.string  "txn"
    t.integer "invoice_id"
    t.integer "status"
    t.text    "description", limit: 65535
  end

  create_table "projects", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.string   "name"
    t.integer  "client_id"
    t.datetime "creation_time"
    t.integer  "private_key"
    t.integer  "kind",          default: 0
    t.integer  "source"
    t.integer  "alias_id"
  end

  create_table "purchased_keyword_packages", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci" do |t|
    t.integer  "keyword_package_id",                         null: false
    t.integer  "keyword_project_id",                         null: false
    t.decimal  "price",              precision: 8, scale: 2, null: false
    t.integer  "remaining_keywords",                         null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "reminders", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "normal_user_id"
    t.integer  "owner_id"
    t.string   "owner_type"
    t.integer  "event"
    t.datetime "expiration"
    t.string   "website_id"
    t.index ["normal_user_id"], name: "normal_user", using: :btree
    t.index ["owner_type", "owner_id"], name: "owner", using: :btree
    t.index ["website_id"], name: "website_id", using: :btree
  end

  create_table "resource_chats", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "translator_id"
    t.integer  "resource_language_id"
    t.integer  "status"
    t.integer  "need_notify"
    t.integer  "word_count",           default: 0
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "deadline"
    t.integer  "translation_status"
    t.integer  "alias_id"
    t.index ["resource_language_id"], name: "resource_language", using: :btree
    t.index ["translator_id"], name: "translator", using: :btree
  end

  create_table "resource_download_stats", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "resource_download_id"
    t.integer  "total"
    t.integer  "completed"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "imported"
    t.index ["resource_download_id"], name: "parent", using: :btree
  end

  create_table "resource_formats", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.string   "name"
    t.string   "description"
    t.string   "label_delimiter"
    t.string   "text_delimiter"
    t.string   "separator_char"
    t.string   "multiline_char"
    t.string   "end_of_line"
    t.string   "comment_char"
    t.integer  "encoding"
    t.integer  "line_break"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "comment_kind"
    t.integer  "kind",            default: 0
  end

  create_table "resource_languages", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "text_resource_id"
    t.integer  "language_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "version_num",                                default: 0
    t.string   "output_name"
    t.integer  "status",                                     default: 0
    t.integer  "notified",                                   default: 1
    t.decimal  "translation_amount", precision: 8, scale: 2, default: "0.07"
    t.index ["notified"], name: "notified", using: :btree
    t.index ["text_resource_id"], name: "text_resource", using: :btree
  end

  create_table "resource_stats", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "text_resource_id"
    t.integer  "version_num",           default: 0
    t.string   "name"
    t.integer  "count"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "resource_language_id"
    t.integer  "resource_language_rev"
  end

  create_table "resource_strings", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "text_resource_id"
    t.string   "token"
    t.text     "txt",                limit: 16777215
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "comment",            limit: 65535
    t.integer  "master_string_id"
    t.string   "context"
    t.integer  "max_width"
    t.boolean  "unclear"
    t.text     "formatted_original", limit: 65535
    t.integer  "resource_upload_id"
    t.integer  "word_count"
    t.index ["master_string_id"], name: "master_string", using: :btree
    t.index ["resource_upload_id"], name: "index_resource_strings_on_resource_upload_id", using: :btree
    t.index ["text_resource_id"], name: "text_resource", using: :btree
  end

  create_table "resource_upload_formats", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer "resource_upload_id"
    t.integer "resource_format_id"
    t.integer "include_affiliate"
  end

  create_table "revision_categories", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer "revision_id"
    t.integer "category_id"
  end

  create_table "revision_languages", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer "revision_id"
    t.integer "language_id"
    t.integer "no_bidding",  default: 0
    t.index ["revision_id", "language_id"], name: "single_rl", unique: true, using: :btree
  end

  create_table "revision_support_files", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer "revision_id"
    t.integer "support_file_id"
  end

  create_table "revisions", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "project_id"
    t.text     "description",                 limit: 65535
    t.integer  "language_id"
    t.string   "name"
    t.integer  "released"
    t.decimal  "max_bid",                                   precision: 8, scale: 2, default: "0.0"
    t.integer  "max_bid_currency"
    t.integer  "bidding_duration"
    t.integer  "project_completion_duration"
    t.datetime "release_date"
    t.datetime "creation_time"
    t.datetime "bidding_close_time"
    t.integer  "alert_status",                                                      default: 0
    t.integer  "private_key"
    t.decimal  "auto_accept_amount",                        precision: 8, scale: 2, default: "0.0"
    t.integer  "kind",                                                              default: 0
    t.integer  "cms_request_id"
    t.integer  "update_counter",                                                    default: 0
    t.integer  "is_test",                                                           default: 0
    t.integer  "notified",                                                          default: 1
    t.integer  "word_count"
    t.text     "note",                        limit: 65535
    t.boolean  "flag",                                                              default: false
    t.boolean  "force_display_on_ta"
    t.index ["bidding_close_time"], name: "index_bidding_close_time", using: :btree
    t.index ["cms_request_id"], name: "cms_request", using: :btree
    t.index ["notified"], name: "notified", using: :btree
    t.index ["project_id"], name: "project", using: :btree
  end

  create_table "schema_info", id: false, force: :cascade, options: "ENGINE=MyISAM DEFAULT CHARSET=utf8" do |t|
    t.integer "version"
  end

  create_table "search_engines", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.string "name"
  end

  create_table "search_urls", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer "search_engine_id"
    t.integer "language_id"
    t.string  "url"
  end

  create_table "sent_notifications", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.string   "owner_type"
    t.integer  "owner_id"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "code"
    t.index ["owner_type", "owner_id"], name: "notification_owner", using: :btree
    t.index ["owner_type", "owner_id"], name: "owner", using: :btree
    t.index ["user_id"], name: "user", using: :btree
  end

  create_table "serial_numbers", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
  end

  create_table "session_tracks", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.string  "type"
    t.integer "resource_id"
    t.integer "user_session_id"
    t.index ["type", "resource_id", "user_session_id"], name: "all_values", unique: true, using: :btree
  end

  create_table "sessions", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.string   "session_id"
    t.text     "data",       limit: 4294967295
    t.datetime "updated_at"
    t.index ["session_id"], name: "index_sessions_on_session_id", using: :btree
    t.index ["updated_at"], name: "index_sessions_on_updated_at", using: :btree
  end

  create_table "shortcodes", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.string   "shortcode"
    t.integer  "website_id"
    t.boolean  "enabled",         default: true
    t.string   "content_type"
    t.string   "comment"
    t.integer  "created_by"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "include_content", default: true
    t.index ["shortcode", "website_id"], name: "websites_shortcodes_unique", unique: true, using: :btree
    t.index ["website_id"], name: "websites_shortcodes", using: :btree
  end

  create_table "site_notices", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "active"
    t.datetime "start_time"
    t.datetime "end_time"
    t.text     "txt",        limit: 65535
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "statistics", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer "version_id"
    t.integer "stat_code"
    t.integer "language_id"
    t.integer "status"
    t.integer "count"
    t.integer "dest_language_id"
    t.index ["version_id"], name: "version", using: :btree
  end

  create_table "string_translations", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "resource_string_id"
    t.integer  "language_id"
    t.text     "txt",                limit: 16777215
    t.integer  "status",                                                      default: 1
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "pay_translator",                                              default: 0
    t.integer  "lock_version",                                                default: 0
    t.integer  "last_editor_id"
    t.decimal  "size_ratio",                          precision: 8, scale: 2
    t.integer  "review_status",                                               default: 0
    t.integer  "pay_reviewer",                                                default: 0
    t.index ["resource_string_id", "language_id"], name: "parent_and_language", unique: true, using: :btree
    t.index ["resource_string_id", "status", "language_id"], name: "parent", using: :btree
    t.index ["resource_string_id", "status", "language_id"], name: "parent_language_and_status", using: :btree
  end

  create_table "subscriptions", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "user_id"
    t.integer  "owner_id"
    t.string   "owner_type"
    t.integer  "kind"
    t.integer  "status"
    t.decimal  "amount",         precision: 8, scale: 2, default: "0.0"
    t.datetime "paid_date"
    t.datetime "expires_date"
    t.integer  "renew_duration"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "super_translators", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1" do |t|
    t.string "email"
  end

  create_table "support_departments", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.string "name"
    t.string "description"
  end

  create_table "support_tickets", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "normal_user_id"
    t.integer  "supporter_id"
    t.integer  "support_department_id"
    t.text     "subject",               limit: 65535
    t.integer  "status"
    t.datetime "create_time"
    t.string   "object_type"
    t.integer  "object_id"
    t.text     "note",                  limit: 65535
    t.index ["normal_user_id"], name: "normal_user", using: :btree
    t.index ["supporter_id"], name: "supporter", using: :btree
  end

  create_table "tags", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.string  "type"
    t.integer "object_id"
    t.string  "object_type"
    t.string  "contents"
  end

  create_table "temp_downloads", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "user_id"
    t.string   "title"
    t.string   "description"
    t.text     "body",        limit: 65535
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "testimonials", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4" do |t|
    t.text     "testimonial",    limit: 65535,             null: false
    t.string   "link_to_app"
    t.string   "testimonial_by",                           null: false
    t.integer  "owner_id"
    t.string   "owner_type"
    t.integer  "rating",                       default: 0
    t.datetime "created_at",                               null: false
    t.datetime "updated_at",                               null: false
  end

  create_table "text_resources", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "client_id"
    t.integer  "language_id"
    t.integer  "resource_format_id"
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "description",          limit: 4294967295,                 collation: "utf8mb4_bin"
    t.integer  "version_num",                             default: 0
    t.integer  "owner_id"
    t.string   "owner_type"
    t.integer  "ignore_duplicates",                       default: 0
    t.string   "required_text"
    t.integer  "check_standard_regex",                    default: 1
    t.integer  "is_public",                               default: 0
    t.integer  "tm_use_mode",                             default: 0
    t.integer  "tm_use_threshold",                        default: 5
    t.integer  "purge_step"
    t.integer  "category_id"
    t.text     "note",                 limit: 65535
    t.boolean  "flag",                                    default: false
    t.integer  "alias_id"
    t.text     "extra_contexts",       limit: 65535
    t.boolean  "add_bom",                                 default: false
  end

  create_table "text_results", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.string   "owner_type"
    t.integer  "owner_id"
    t.string   "kind"
    t.text     "txt",        limit: 65535
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "tmt_configs", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4" do |t|
    t.integer  "cms_request_id"
    t.integer  "translator_id"
    t.boolean  "enabled",        default: false
    t.datetime "created_at",                     null: false
    t.datetime "updated_at",                     null: false
  end

  create_table "translated_memories", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "client_id"
    t.integer  "language_id"
    t.integer  "translation_memory_id"
    t.integer  "translator_id"
    t.text     "content",               limit: 65535,                          collation: "utf8mb4_bin"
    t.text     "raw_content",           limit: 65535,                          collation: "utf8mb4_bin"
    t.datetime "created_at",                                      null: false
    t.datetime "updated_at",                                      null: false
    t.integer  "tm_status",                           default: 0
    t.index ["translation_memory_id"], name: "index_translated_memories_on_translation_memory_id", using: :btree
  end

  create_table "translation_analytics_language_pairs", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer "translation_analytics_profile_id"
    t.integer "to_language_id"
    t.integer "from_language_id"
    t.integer "estimate_time_rate"
    t.date    "deadline"
  end

  create_table "translation_analytics_profiles", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer "project_id",                                                 null: false
    t.string  "project_type",                    limit: 32,                 null: false
    t.integer "deadline_threshold",                         default: 0,     null: false
    t.boolean "no_translation_progress_alert",              default: true
    t.integer "no_translation_progress_days",               default: 3
    t.integer "missed_estimated_deadline_days",             default: 3
    t.boolean "missed_estimated_deadline_alert",            default: true
    t.boolean "configured",                                 default: false
  end

  create_table "translation_memories", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "client_id"
    t.integer  "language_id"
    t.string   "signature"
    t.string   "raw_signature",                                             collation: "utf8_bin"
    t.text     "content",       limit: 4294967295,                          collation: "utf8mb4_bin"
    t.text     "raw_content",   limit: 4294967295,                          collation: "utf8mb4_bin"
    t.datetime "created_at",                                   null: false
    t.datetime "updated_at",                                   null: false
    t.integer  "word_count",                       default: 0
    t.index ["language_id", "client_id", "signature"], name: "translation_memories_index_1", using: :btree
    t.index ["signature"], name: "index_translation_memories_on_signature", using: :btree
  end

  create_table "translation_snapshots", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "translation_analytics_language_pair_id"
    t.datetime "date",                                   null: false
    t.integer  "words_to_translate"
    t.integer  "translated_words"
    t.integer  "words_to_review"
    t.integer  "reviewed_words"
    t.integer  "total_issues"
    t.integer  "unresolved_issues"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "translator_categories", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer "translator_id"
    t.integer "category_id"
  end

  create_table "translator_languages", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.string  "type"
    t.integer "translator_id"
    t.integer "language_id"
    t.integer "status",                      default: 0
    t.text    "description",   limit: 65535
  end

  create_table "translator_languages_auto_assignments", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1" do |t|
    t.integer "translator_id"
    t.integer "from_language_id",                           null: false
    t.integer "to_language_id",                             null: false
    t.decimal "min_price_per_word", precision: 4, scale: 2
    t.string  "language_pair_id"
    t.index ["language_pair_id"], name: "index_translator_languages_auto_assignments_on_language_pair_id", using: :btree
    t.index ["translator_id", "from_language_id", "to_language_id"], name: "translator_language_pair", unique: true, using: :btree
    t.index ["translator_id"], name: "index_translator_languages_auto_assignments_on_translator_id", using: :btree
  end

  create_table "translators_refused_projects", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1" do |t|
    t.integer  "translator_id",               null: false
    t.string   "owner_type"
    t.integer  "owner_id"
    t.text     "remarks",       limit: 65535
    t.string   "project_type",                null: false
    t.datetime "created_at",                  null: false
    t.datetime "updated_at",                  null: false
    t.index ["owner_type", "owner_id"], name: "index_translators_refused_projects_on_owner_type_and_owner_id", using: :btree
  end

  create_table "translators_translated_memories", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4" do |t|
    t.integer  "client_id"
    t.integer  "language_id"
    t.integer  "translators_translation_memory_id"
    t.integer  "translator_id"
    t.text     "content",                           limit: 4294967295,              collation: "utf8mb4_bin"
    t.text     "raw_content",                       limit: 4294967295,              collation: "utf8mb4_bin"
    t.integer  "tm_status"
    t.datetime "created_at",                                           null: false
    t.datetime "updated_at",                                           null: false
  end

  create_table "translators_translation_memories", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4" do |t|
    t.integer  "translator_id"
    t.integer  "language_id"
    t.string   "signature"
    t.string   "raw_signature"
    t.text     "content",       limit: 4294967295,              collation: "utf8mb4_bin"
    t.text     "raw_content",   limit: 4294967295,              collation: "utf8mb4_bin"
    t.integer  "word_count"
    t.datetime "created_at",                       null: false
    t.datetime "updated_at",                       null: false
  end

  create_table "upload_translations", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "resource_upload_id"
    t.integer  "resource_download_id"
    t.integer  "language_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "user_clicks", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "user_id"
    t.string   "controller"
    t.string   "action"
    t.string   "params"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "resource_id"
    t.text     "url",         limit: 65535
    t.string   "method"
    t.string   "error"
    t.text     "log",         limit: 65535
  end

  create_table "user_downloads", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "user_id"
    t.integer  "download_id"
    t.datetime "download_time"
  end

  create_table "user_sessions", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "user_id"
    t.string   "session_num"
    t.datetime "login_time"
    t.integer  "display"
    t.integer  "counter",     default: 0, null: false
    t.integer  "tracked",     default: 0
    t.integer  "long_life"
    t.index ["session_num"], name: "session_num", unique: true, using: :btree
  end

  create_table "user_tokens", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1" do |t|
    t.integer  "user_id"
    t.string   "token"
    t.datetime "created_at",                 null: false
    t.datetime "updated_at",                 null: false
    t.boolean  "used",       default: false
  end

  create_table "users", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.string   "type"
    t.string   "fname"
    t.string   "lname"
    t.string   "email",                                                                                collation: "utf8_bin"
    t.string   "nickname",                                                                             collation: "utf8_bin"
    t.integer  "verification_level",                                                   default: 0
    t.integer  "userstatus"
    t.string   "loc_code"
    t.integer  "notifications"
    t.datetime "signup_date"
    t.integer  "sent_messages",                                                        default: 0
    t.integer  "affiliate_id"
    t.integer  "country_id"
    t.string   "zip_code"
    t.integer  "scanned_for_languages",                                                default: 0
    t.datetime "last_login"
    t.string   "next_operation"
    t.integer  "available_for_cms"
    t.string   "source"
    t.string   "company"
    t.string   "title"
    t.string   "url"
    t.integer  "is_public"
    t.decimal  "rating",                                       precision: 8, scale: 2, default: "0.0"
    t.integer  "level",                                                                default: 0
    t.integer  "anon",                                                                 default: 0
    t.integer  "jobs_in_progress"
    t.integer  "capacity"
    t.decimal  "rate",                                         precision: 8, scale: 2, default: "0.0"
    t.integer  "display_options",                                                      default: 0
    t.integer  "raw_rating"
    t.string   "phone_country"
    t.string   "phone_number"
    t.boolean  "follow_up_email"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "cat"
    t.boolean  "smartphone"
    t.boolean  "top"
    t.boolean  "sent_logo",                                                            default: false
    t.integer  "master_account"
    t.text     "note",                           limit: 65535
    t.boolean  "flag"
    t.integer  "master_account_id"
    t.boolean  "reverse_tm",                                                           default: false
    t.date     "birthday"
    t.boolean  "bounced",                                                              default: false
    t.boolean  "send_admin_notifications",                                             default: true
    t.boolean  "skip_instant_translation_email",                                       default: false
    t.string   "last_ip"
    t.integer  "last_ip_country_id"
    t.string   "vat_number"
    t.boolean  "is_business_vat"
    t.integer  "ta_limit",                                                             default: 50
    t.boolean  "allowed_to_withdraw"
    t.string   "hash_password",                                                                        collation: "utf8_bin"
    t.string   "supporter_password"
    t.datetime "supporter_password_expiration"
    t.boolean  "beta_user",                                                            default: false
    t.string   "api_key"
    t.boolean  "ta_blocked",                                                           default: false
    t.index ["api_key"], name: "api_key", unique: true, using: :btree
    t.index ["email"], name: "email", unique: true, using: :btree
    t.index ["level"], name: "level", using: :btree
    t.index ["nickname"], name: "nickname", unique: true, using: :btree
    t.index ["rating"], name: "rating", using: :btree
    t.index ["type"], name: "type", using: :btree
    t.index ["userstatus"], name: "userstatus", using: :btree
  end

  create_table "vacations", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "user_id"
    t.datetime "beginning"
    t.datetime "ending"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "visits", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "destination_id"
    t.string   "source"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "vouchers", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.string  "code"
    t.boolean "active"
    t.decimal "amount",                 precision: 8, scale: 2, default: "0.0"
    t.text    "comments", limit: 65535
  end

  create_table "web_attachments", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer "web_message_id"
    t.string  "content_type"
    t.string  "filename"
    t.integer "size"
    t.integer "parent_id"
    t.boolean "backup_on_s3",   default: false
    t.index ["backup_on_s3"], name: "backup_on_s3_idx", using: :btree
  end

  create_table "web_dialogs", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "client_department_id"
    t.integer  "visitor_language_id"
    t.string   "email"
    t.string   "fname"
    t.string   "lname"
    t.string   "visitor_subject"
    t.string   "client_subject"
    t.integer  "status"
    t.integer  "translation_status"
    t.datetime "create_time"
    t.datetime "translate_time"
    t.integer  "accesskey"
    t.boolean  "bounced",              default: false
    t.index ["client_department_id"], name: "client_department", using: :btree
  end

  create_table "web_messages", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "lock_version",                           default: 0
    t.integer  "visitor_language_id"
    t.integer  "client_language_id"
    t.integer  "owner_id"
    t.string   "owner_type"
    t.integer  "user_id"
    t.text     "visitor_body",        limit: 65535
    t.text     "client_body",         limit: 4294967295,             collation: "utf8mb4_bin"
    t.datetime "create_time"
    t.datetime "translate_time"
    t.integer  "word_count"
    t.integer  "money_account_id"
    t.integer  "translator_id"
    t.integer  "translation_status",                     default: 0
    t.text     "name",                limit: 65535
    t.text     "comment",             limit: 65535
    t.integer  "old_format",                             default: 0
    t.integer  "notified",                               default: 1
    t.text     "complex_flag_users",  limit: 65535
    t.index ["notified"], name: "notified", using: :btree
    t.index ["owner_type", "owner_id"], name: "owner", using: :btree
    t.index ["translation_status", "visitor_language_id", "client_language_id", "user_id", "owner_type"], name: "search", using: :btree
    t.index ["translator_id"], name: "translator", using: :btree
    t.index ["user_id"], name: "user", using: :btree
  end

  create_table "web_supports", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "client_id"
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["client_id"], name: "client", using: :btree
  end

  create_table "website_report_formats", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "website_id"
    t.text     "format",          limit: 65535
    t.text     "filter",          limit: 65535
    t.integer  "pagination_kind"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["website_id"], name: "website", using: :btree
  end

  create_table "website_shortcodes", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer "website_id"
    t.integer "shortcode_id"
    t.boolean "enabled"
  end

  create_table "website_translation_contracts", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "website_translation_offer_id"
    t.integer  "translator_id"
    t.integer  "status"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "invited",                                              default: 0
    t.decimal  "amount",                       precision: 8, scale: 2, default: "0.0"
    t.integer  "currency_id"
    t.datetime "accepted_by_client_at"
    t.index ["translator_id"], name: "translator", using: :btree
    t.index ["website_translation_offer_id"], name: "website_translation_offer", using: :btree
  end

  create_table "website_translation_offers", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "website_id"
    t.integer  "from_language_id"
    t.integer  "to_language_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "url"
    t.string   "login"
    t.string   "password"
    t.integer  "blogid"
    t.integer  "status",                                        default: 0
    t.text     "invitation",                      limit: 65535
    t.text     "sample_text",                     limit: 65535
    t.integer  "notified",                                      default: 1
    t.boolean  "automatic_translator_assignment"
    t.boolean  "invited_all_translators"
    t.integer  "active_trail_action_id"
    t.index ["active_trail_action_id"], name: "index_website_translation_offers_on_active_trail_action_id", using: :btree
    t.index ["notified"], name: "notified", using: :btree
    t.index ["website_id"], name: "website", using: :btree
  end

  create_table "websites", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "client_id"
    t.string   "name"
    t.text     "description",           limit: 65535
    t.integer  "platform_kind"
    t.integer  "platform_version"
    t.string   "url"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "login"
    t.string   "password"
    t.integer  "blogid"
    t.integer  "pickup_type",                         default: 0
    t.integer  "interview_translators",               default: 1
    t.integer  "notifications",                       default: 0
    t.integer  "free_usage",                          default: 0
    t.integer  "accesskey_ok",                        default: 0
    t.integer  "project_kind",                        default: 2
    t.integer  "cms_kind",                            default: 0
    t.string   "cms_description"
    t.string   "xmlrpc_path"
    t.integer  "free_support",                        default: 0
    t.text     "note",                  limit: 65535
    t.integer  "flag",                                default: 0
    t.string   "accesskey"
    t.integer  "anon",                                default: 0
    t.integer  "category_id"
    t.integer  "word_count"
    t.text     "wc_description",        limit: 65535
    t.integer  "tm_use_mode",                         default: 0
    t.integer  "tm_use_threshold",                    default: 3
    t.string   "api_version"
    t.boolean  "dummy",                               default: false
    t.boolean  "migrated_to_tp",                      default: false
    t.boolean  "mt_enabled",                          default: true
    t.string   "encrypted_wp_username"
    t.string   "encrypted_wp_password"
    t.string   "wp_login_url"
    t.index ["client_id"], name: "client", using: :btree
  end

  create_table "withdrawals", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.datetime "submit_time"
  end

  create_table "xliff_trans_unit_mrks", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "xliff_trans_unit_id"
    t.integer  "mrk_type"
    t.integer  "mrk_id"
    t.string   "trans_unit_id"
    t.integer  "language_id"
    t.string   "top_content"
    t.string   "bottom_content",                           default: "</mrk>"
    t.text     "content",               limit: 4294967295,                                 collation: "utf8mb4_bin"
    t.integer  "translation_memory_id"
    t.integer  "translated_memory_id"
    t.datetime "created_at",                                                  null: false
    t.datetime "updated_at",                                                  null: false
    t.integer  "mrk_status",                               default: 0
    t.integer  "source_id"
    t.integer  "target_id"
    t.integer  "xliff_id"
    t.integer  "cms_request_id"
    t.integer  "client_id"
    t.integer  "word_count",                               default: 0
    t.integer  "tm_word_count",                            default: 0
    t.datetime "deleted_at"
    t.index ["client_id"], name: "client_id", using: :btree
    t.index ["cms_request_id"], name: "cms_request_id", using: :btree
    t.index ["deleted_at", "xliff_trans_unit_id", "mrk_type"], name: "xliff_trans_unit_mrks_index_1", using: :btree
    t.index ["deleted_at"], name: "index_xliff_trans_unit_mrks_on_deleted_at", using: :btree
    t.index ["language_id"], name: "language_id", using: :btree
    t.index ["source_id"], name: "source_id", using: :btree
    t.index ["target_id"], name: "target_id", using: :btree
    t.index ["translated_memory_id"], name: "translated_memory_id", using: :btree
    t.index ["translation_memory_id"], name: "translation_memory_id", using: :btree
    t.index ["xliff_id"], name: "xliff_id", using: :btree
    t.index ["xliff_trans_unit_id"], name: "xliff_trans_unit_id", using: :btree
  end

  create_table "xliff_trans_units", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.integer  "parsed_xliff_id"
    t.string   "trans_unit_id"
    t.integer  "source_language_id"
    t.integer  "target_language_id"
    t.text     "top_content",        limit: 65535
    t.text     "bottom_content",     limit: 65535
    t.text     "source",             limit: 4294967295,              collation: "utf8mb4_bin"
    t.datetime "created_at",                            null: false
    t.datetime "updated_at",                            null: false
    t.index ["parsed_xliff_id"], name: "parsed_xliff_id", using: :btree
    t.index ["source_language_id"], name: "source_language_id", using: :btree
    t.index ["target_language_id"], name: "target_language_id", using: :btree
  end

  create_table "xliffs", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.string  "content_type"
    t.string  "filename"
    t.integer "size"
    t.integer "cms_request_id"
    t.boolean "translated",     default: false
    t.boolean "backup_on_s3",   default: false
    t.boolean "processed",      default: false
    t.index ["backup_on_s3"], name: "backup_on_s3_idx", using: :btree
  end

  create_table "zipped_files", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8" do |t|
    t.string   "type"
    t.integer  "owner_id"
    t.datetime "chgtime"
    t.string   "description"
    t.string   "content_type"
    t.string   "filename"
    t.integer  "size"
    t.integer  "parent_id"
    t.integer  "by_user_id"
    t.string   "aws_s3_path"
    t.boolean  "backup_on_s3", default: false
    t.integer  "status",       default: 0
    t.index ["backup_on_s3"], name: "backup_on_s3_idx", using: :btree
    t.index ["type", "owner_id"], name: "owner", using: :btree
  end

  add_foreign_key "cms_requests", "invoices"
  add_foreign_key "language_pair_fixed_prices", "languages", column: "from_language_id"
  add_foreign_key "language_pair_fixed_prices", "languages", column: "to_language_id"
  add_foreign_key "translator_languages_auto_assignments", "users", column: "translator_id"
  add_foreign_key "website_translation_offers", "active_trail_actions"
end
