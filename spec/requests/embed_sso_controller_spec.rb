require 'rails_helper'

RSpec.describe 'Embedded agent SSO', type: :request do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }

  def embed_query(sso_auth_token:)
    {
      email: user.email,
      sso_auth_token: sso_auth_token,
      sso_account_id: account.id,
      redirect_url: 'conversations?embed=1'
    }
  end

  describe 'GET /app/embed_sso' do
    it 'auto-posts the one-time token, sets the dashboard cookie, and opens embed conversations' do
      token = user.generate_sso_auth_token

      get '/app/embed_sso', params: embed_query(sso_auth_token: token)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('method="post"')

      post '/app/embed_sso', params: embed_query(sso_auth_token: token)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("/app/accounts/#{account.id}/conversations?embed=1")

      cookie = response.cookies['cw_d_session_info']
      expect(cookie).to be_present
      payload = JSON.parse(cookie)
      expect(payload).to include('access-token', 'client', 'uid')

      get "/app/accounts/#{account.id}/conversations",
          params: { embed: '1' },
          headers: {
            'access-token' => payload['access-token'],
            'token-type' => payload['token-type'],
            'client' => payload['client'],
            'expiry' => payload['expiry'],
            'uid' => payload['uid']
          }
      expect(response).to have_http_status(:ok)
    end

    it 'rejects a token after it has been used' do
      token = user.generate_sso_auth_token
      post '/app/embed_sso', params: embed_query(sso_auth_token: token)
      reset!

      post '/app/embed_sso', params: embed_query(sso_auth_token: token)

      expect(response).to redirect_to(%r{/app/login\?error=access-denied})
    end

    it 'leaves missing credentials on the login page' do
      get '/app/embed_sso', params: { email: user.email }

      expect(response).to redirect_to(%r{/app/login\?error=access-denied})
    end
  end
end
