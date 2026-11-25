# frozen_string_literal: true

module EmbeddedDashboardCookies
  DASHBOARD_SESSION_COOKIE = 'cw_d_session_info'

  COOKIE_HEADER_KEYS = %w[access-token token-type client expiry uid].freeze

  module_function

  def secure_embed_cookies?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch('FORCE_SSL', false)) ||
      ENV.fetch('FRONTEND_URL', '').start_with?('https://')
  end

  def session_payload(auth_headers)
    normalized = auth_headers.stringify_keys
    COOKIE_HEADER_KEYS.index_with { |key| normalized.fetch(key) }
  end

  def write_session_info!(cookies, auth_headers)
    payload = session_payload(auth_headers)
    expiry = payload.fetch('expiry').to_i
    options = {
      value: payload.to_json,
      path: '/',
      httponly: false,
      expires: Time.zone.at(expiry)
    }

    if secure_embed_cookies?
      options[:secure] = true
      options[:same_site] = :none
      options[:partitioned] = true
    else
      options[:same_site] = :lax
    end

    cookies[DASHBOARD_SESSION_COOKIE] = options
  end
end
