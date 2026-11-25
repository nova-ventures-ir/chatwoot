# frozen_string_literal: true

class EmbeddedAgentSsoService
  class SsoError < StandardError; end

  def initialize(request:)
    @request = request
  end

  def user_for_sso(email:, sso_auth_token:)
    return if email.blank? || sso_auth_token.blank?

    user = User.from_email(email.strip.downcase)
    return unless user&.valid_sso_auth_token?(sso_auth_token)
    return if user.sso_auth_token_impersonation?(sso_auth_token)

    user
  end

  def complete_sign_in!(user:, sso_auth_token:)
    raise SsoError, 'invalid_token' unless user.valid_sso_auth_token?(sso_auth_token)

    ensure_session_capacity!(user)

    token = user.create_token
    user.save!
    user.invalidate_sso_auth_token(sso_auth_token)

    headers = user.build_auth_headers(token.token, token.client)
    track_session!(user, token.client)
    headers
  end

  private

  def ensure_session_capacity!(user)
    limit = ENV.fetch('MAX_USER_SESSIONS', 25).to_i
    return unless active_token_count(user) >= limit

    evict_oldest_session(user)
  end

  def active_token_count(user)
    now = Time.current.to_i
    (user.tokens || {}).count { |_, value| value['expiry'].to_i > now }
  end

  def evict_oldest_session(user)
    return evict_oldest_token(user) if user.user_sessions.count < user.tokens.size

    oldest_session = user.user_sessions.order(Arel.sql('COALESCE(last_activity_at, created_at) ASC')).first
    return evict_oldest_token(user) unless oldest_session

    user.tokens.delete(oldest_session.client_id)
    user.save!
    oldest_session.destroy!
  end

  def evict_oldest_token(user)
    return if user.tokens.blank?

    oldest_client_id = user.tokens.min_by { |_, value| value['expiry'].to_i }&.first
    return unless oldest_client_id

    user.tokens.delete(oldest_client_id)
    user.save!
  end

  def track_session!(user, client_id)
    UserSessionTrackingService.new(
      user: user,
      request: @request,
      client_id: client_id
    ).create_or_update!
  rescue StandardError => e
    Rails.logger.warn "Session tracking failed: #{e.message}"
  end
end
