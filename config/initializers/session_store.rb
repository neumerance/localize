# Be sure to restart your server when you modify this file.

# Icanlocalize::Application.config.session_store :cookie_store, :key => '_icanlocalize_session'

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rails generate session_migration")
# Icanlocalize::Application.config.session_store :active_record_store, key: '_icanlocalize_session'

if COOKIE_STORE_ENABLED
  Icanlocalize::Application.config.session_store :cookie_store, key: '_icanlocalize_session'
else
  Icanlocalize::Application.config.session_store :active_record_store, key: '_icanlocalize_session'
end
