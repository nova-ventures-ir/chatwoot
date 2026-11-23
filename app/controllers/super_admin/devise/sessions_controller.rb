# frozen_string_literal: true

class SuperAdmin::Devise::SessionsController < Devise::SessionsController
  MFA_CHALLENGE_EXPIRY = 5.minutes
  MFA_MAX_FAILED_ATTEMPTS = 5
  MFA_FAILED_ATTEMPTS_WINDOW = 15.minutes

  def new
    @mfa_challenge = pending_mfa_super_admin.present?
    self.resource = resource_class.new(sign_in_params)
  end

  # The panel loads this inside a cross-site iframe. A 302 drops the session cookie
  # before the next request, so the browser lands on the login page. GET only checks
  # the token. POST signs in and the page then navigates on the Chatwoot origin.
  def sso
    return render_sso_auto_post if request.get?

    admin = valid_sso_super_admin
    if admin&.consume_sso_auth_token(sso_token)
      sign_in(:super_admin, admin)
      flash.discard
    elsif !already_signed_in_sso_admin?
      return redirect_to(new_super_admin_session_path)
    end

    render template: 'super_admin/devise/sessions/sso_complete', layout: false
  end

  def create
    return verify_mfa_code if mfa_code_submission?

    redirect_to(super_admin_session_path, flash: { error: @error_message }) && return unless valid_credentials?
    return start_mfa_challenge if @super_admin.mfa_enabled?

    complete_sign_in(@super_admin)
  end

  def destroy
    sign_out
    flash.discard
    redirect_to '/'
  end

  private

  def valid_credentials?
    @super_admin = SuperAdmin.find_by!(email: params[:super_admin][:email])
    raise StandardError, 'Invalid Password' unless @super_admin.valid_password?(params[:super_admin][:password])

    true
  rescue StandardError => e
    Rails.logger.error e.message
    @error_message = 'Invalid credentials. Please try again.'
    false
  end

  def mfa_code_submission?
    scoped_params = params[:super_admin]
    scoped_params.respond_to?(:key?) && !scoped_params[:otp_code].nil?
  end

  def start_mfa_challenge
    session[:super_admin_mfa] = {
      'id' => @super_admin.id,
      'salt' => @super_admin.authenticatable_salt,
      'expires_at' => MFA_CHALLENGE_EXPIRY.from_now.to_i
    }
    redirect_to super_admin_session_path
  end

  def verify_mfa_code
    super_admin = pending_mfa_super_admin
    return redirect_to(super_admin_session_path, flash: { error: I18n.t('super_admin.login.mfa_expired') }) unless super_admin
    return end_mfa_challenge if reserve_mfa_attempt(super_admin) > MFA_MAX_FAILED_ATTEMPTS
    return redirect_to(super_admin_session_path, flash: { error: I18n.t('super_admin.login.mfa_invalid') }) unless valid_mfa_code?(super_admin)

    Redis::Alfred.delete(mfa_failed_attempts_key(super_admin))
    session.delete(:super_admin_mfa)
    complete_sign_in(super_admin)
  end

  def reserve_mfa_attempt(super_admin)
    key = mfa_failed_attempts_key(super_admin)
    Redis::Alfred.incr(key).tap { |attempts| Redis::Alfred.expire(key, MFA_FAILED_ATTEMPTS_WINDOW) if attempts == 1 }
  end

  def end_mfa_challenge
    session.delete(:super_admin_mfa)
    redirect_to(super_admin_session_path, flash: { error: I18n.t('super_admin.login.mfa_attempts_exhausted') })
  end

  def mfa_failed_attempts_key(super_admin)
    format(Redis::RedisKeys::SUPER_ADMIN_MFA_FAILED_ATTEMPTS, user_id: super_admin.id)
  end

  def valid_mfa_code?(super_admin)
    code = params[:super_admin][:otp_code].to_s.strip
    otp_code, backup_code = code.match?(/\A\d{6}\z/) ? [code, nil] : [nil, code.upcase]

    Mfa::AuthenticationService.new(user: super_admin, otp_code: otp_code, backup_code: backup_code).authenticate
  end

  def pending_mfa_super_admin
    challenge = session[:super_admin_mfa]
    return if challenge.blank?

    super_admin = SuperAdmin.find_by(id: challenge['id']) if challenge['expires_at'].to_i >= Time.current.to_i
    return super_admin if super_admin && ActiveSupport::SecurityUtils.secure_compare(super_admin.authenticatable_salt.to_s, challenge['salt'].to_s)

    session.delete(:super_admin_mfa)
    nil
  end

  def render_sso_auto_post
    return redirect_to(new_super_admin_session_path) unless valid_sso_super_admin

    render template: 'super_admin/devise/sessions/sso_auto_post',
           layout: false,
           locals: { email: params[:email].to_s, token: sso_token }
  end

  def valid_sso_super_admin
    admin = SuperAdmin.from_email(params[:email])
    admin if admin&.valid_sso_auth_token?(sso_token)
  end

  def already_signed_in_sso_admin?
    current_super_admin.present? && current_super_admin.email == params[:email].to_s.downcase
  end

  def sso_token
    params[:sso_auth_token].to_s
  end

  def complete_sign_in(super_admin)
    sign_in(:super_admin, super_admin)
    flash.discard
    redirect_to after_sign_in_path_for(:super_admin)
  end
end
