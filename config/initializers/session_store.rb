# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_biomart_session',
  :secret      => '8b05f0dcc76c4eed6124f3f4da7b668821d71c854bf12ddbfd360426aadda098bc5096604a1fe8fcf2dce0b6a53a798b0ba26c22fd7a0f5099e18ca5fa45aa53'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store
