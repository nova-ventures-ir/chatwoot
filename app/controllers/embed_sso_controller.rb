# frozen_string_literal: true

class EmbedSsoController < ApplicationController
  SSO_PARAMS = %i[email sso_auth_token redirect_url sso_account_id].freeze

  # Cross-site panel iframes cannot keep the agent session after a JS sign-in.
  # GET only checks the one-time token; POST consumes it, sets a partitioned
  # dashboard cookie, then navigates on the Chatwoot origin.
  def sso
    user = sso_service.user_for_sso(email: params[:email], sso_auth_token: params[:sso_auth_token])
    return redirect_to_login unless user

    return render_embed_sso_post if request.get?

    complete_embed_sso!(user)
  rescue EmbeddedAgentSsoService::SsoError
    redirect_to_login
  end

  private

  def sso_service
    @sso_service ||= EmbeddedAgentSsoService.new(request: request)
  end

  def sso_fields
    sso_fields_from_params.stringify_keys
  end

  def sso_fields_from_params
    params.permit(*SSO_PARAMS).to_h.compact_blank
  end

  def render_embed_sso_post
    @sso_fields = sso_fields
    render 'embed_sso/auto_post', layout: false
  end

  def complete_embed_sso!(user)
    headers = sso_service.complete_sign_in!(user: user, sso_auth_token: params[:sso_auth_token])
    destination = EmbeddedAgentSsoRedirect.destination(
      user: user.reload,
      sso_account_id: params[:sso_account_id],
      redirect_url: params[:redirect_url]
    )
    return redirect_to_login unless destination

    EmbeddedDashboardCookies.write_session_info!(cookies, headers)
    @destination = destination
    render 'embed_sso/complete', layout: false
  end

  def redirect_to_login
    redirect_to '/app/login?error=access-denied'
  end
end
