require 'rails_helper'

RSpec.describe 'Platform Super Admin API', type: :request do
  let(:platform_app) { create(:platform_app) }
  let(:headers) { { api_access_token: platform_app.access_token.token } }
  let(:params) do
    { name: 'Mina Nouri', email: 'super.user-1@support.invalid', custom_attributes: { nova_user_id: 'user-1' } }
  end

  describe 'POST /platform/api/v1/super_admin/login' do
    it 'returns unauthorized without a platform token' do
      post '/platform/api/v1/super_admin/login', params: params, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'creates a super admin and returns a one-time login url' do
      with_modified_env FRONTEND_URL: 'https://chat.example' do
        post '/platform/api/v1/super_admin/login', params: params, headers: headers, as: :json
      end

      expect(response).to have_http_status(:success)
      admin = SuperAdmin.from_email('super.user-1@support.invalid')
      expect(admin.custom_attributes['nova_user_id']).to eq('user-1')
      expect(response.parsed_body['url']).to start_with('https://chat.example/super_admin/sso/')
      expect(response.parsed_body['url']).not_to include('sso_auth_token')
      expect(platform_app.platform_app_permissibles.where(permissible: admin)).to exist
    end

    it 'reuses the super admin linked to the same nova user' do
      existing = create(:super_admin, email: 'super.user-1@support.invalid', custom_attributes: { 'nova_user_id' => 'user-1' })

      post '/platform/api/v1/super_admin/login', params: params, headers: headers, as: :json

      expect(response).to have_http_status(:success)
      expect(SuperAdmin.where(email: existing.email).count).to eq(1)
    end

    it 'rejects an email that already belongs to an agent' do
      create(:user, email: 'super.user-1@support.invalid')

      post '/platform/api/v1/super_admin/login', params: params, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'rejects a super admin linked to a different nova user' do
      create(:super_admin, email: 'super.user-1@support.invalid', custom_attributes: { 'nova_user_id' => 'other' })

      post '/platform/api/v1/super_admin/login', params: params, headers: headers, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
