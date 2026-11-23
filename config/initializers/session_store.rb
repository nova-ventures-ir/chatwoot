# Be sure to restart your server when you modify this file.
# Sessions are used only for the super_admin dashboard (flash/CSRF), not for API auth.
# Panels embed that dashboard on another host. SameSite=None and Partitioned let the
# session survive inside the iframe when the public URL is HTTPS. HTTP dev stays Lax.

secure_cookies = ActiveModel::Type::Boolean.new.cast(ENV.fetch('FORCE_SSL', false)) ||
                 ENV.fetch('FRONTEND_URL', '').start_with?('https://')

Rails.application.config.session_store :cookie_store,
                                       key: '_chatwoot_session',
                                       same_site: secure_cookies ? :none : :lax,
                                       secure: secure_cookies,
                                       partitioned: secure_cookies,
                                       httponly: true
