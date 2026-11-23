require 'rails_helper'

RSpec.describe EmbedFrameAncestors do
  subject(:middleware) { described_class.new(app) }

  let(:app) { ->(_env) { [200, { 'Content-Type' => 'text/html' }, ['ok']] } }

  it 'lets the dashboard embed origins frame the app' do
    with_modified_env EMBED_FRAME_ANCESTORS: 'http://localhost:4300' do
      _status, headers, _body = middleware.call('PATH_INFO' => '/app')

      expect(headers['Content-Security-Policy']).to eq('frame-ancestors http://localhost:4300')
      expect(headers['X-Frame-Options']).to be_nil
    end
  end

  it 'leaves the public website widget frame policy alone' do
    with_modified_env EMBED_FRAME_ANCESTORS: 'http://localhost:4300' do
      _status, headers, _body = middleware.call('PATH_INFO' => '/widget')

      expect(headers['Content-Security-Policy']).to be_nil
    end
  end
end
