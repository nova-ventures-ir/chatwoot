require 'rails_helper'

RSpec.describe 'Platform Web Widget API', type: :request do
  let!(:account) { create(:account) }
  let(:platform_app) { create(:platform_app) }
  let(:base_url) { "/platform/api/v1/accounts/#{account.id}/web_widgets" }
  let(:headers) { { api_access_token: platform_app.access_token.token } }
  let(:widget_params) do
    {
      name: 'Landing',
      website_url: 'http://localhost:4200',
      widget_color: '#38477e',
      welcome_title: 'نواونچرز',
      welcome_tagline: 'پیام خود را بنویسید'
    }
  end

  before do
    create(:platform_app_permissible, platform_app: platform_app, permissible: account)
  end

  describe 'POST /platform/api/v1/accounts/:account_id/web_widgets' do
    it 'returns unauthorized without a token' do
      post base_url, params: widget_params, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns unauthorized when the account is not permissible' do
      other_account = create(:account)

      post "/platform/api/v1/accounts/#{other_account.id}/web_widgets",
           params: widget_params,
           headers: headers,
           as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'requires a name and website url' do
      post base_url, params: { name: 'Landing' }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'creates one website inbox' do
      expect do
        post base_url, params: widget_params, headers: headers, as: :json
      end.to change(Channel::WebWidget, :count).by(1).and change(Inbox, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['name']).to eq('Landing')
      expect(response.parsed_body['website_url']).to eq('http://localhost:4200')
      expect(response.parsed_body['website_token']).to be_present
      expect(Channel::WebWidget.last.widget_color).to eq('#38477e')
    end

    it 'updates the existing website inbox instead of creating another' do
      post base_url, params: widget_params, headers: headers, as: :json
      created = response.parsed_body

      post base_url, params: widget_params.merge(welcome_title: 'Hello'), headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['id']).to eq(created['id'])
      expect(response.parsed_body['website_token']).to eq(created['website_token'])
      expect(Channel::WebWidget.last.welcome_title).to eq('Hello')
      expect(Inbox.where(account: account, channel_type: 'Channel::WebWidget').count).to eq(1)
    end
  end

  describe 'POST /platform/api/v1/accounts/:account_id/web_widgets/:id/add_member' do
    let(:user) { create(:user, account: account, role: 'agent') }

    it 'adds an account user to the website inbox once' do
      post base_url, params: widget_params, headers: headers, as: :json
      inbox_id = response.parsed_body['id']

      expect do
        post "#{base_url}/#{inbox_id}/add_member", params: { user_id: user.id }, headers: headers, as: :json
      end.to change(InboxMember, :count).by(1)
      expect(response).to have_http_status(:ok)

      expect do
        post "#{base_url}/#{inbox_id}/add_member", params: { user_id: user.id }, headers: headers, as: :json
      end.not_to change(InboxMember, :count)
    end

    it 'rejects a user who is not on the account' do
      post base_url, params: widget_params, headers: headers, as: :json
      inbox_id = response.parsed_body['id']
      outsider = create(:user)

      post "#{base_url}/#{inbox_id}/add_member", params: { user_id: outsider.id }, headers: headers, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
