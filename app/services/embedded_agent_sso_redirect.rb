# frozen_string_literal: true

class EmbeddedAgentSsoRedirect
  def self.destination(user:, sso_account_id:, redirect_url:)
    account_id = resolve_account_id(user, sso_account_id)
    return if account_id.blank?

    base = "/app/accounts/#{account_id}"
    redirect_url.present? ? "#{base}/#{redirect_url}" : "#{base}/dashboard"
  end

  def self.resolve_account_id(user, sso_account_id)
    if sso_account_id.present?
      account_id = sso_account_id.to_i
      return account_id if user.account_users.exists?(account_id: account_id)
    end

    user.account_users.order(:created_at).pick(:account_id)
  end
end
