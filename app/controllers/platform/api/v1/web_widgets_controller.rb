class Platform::Api::V1::WebWidgetsController < PlatformController
  DEFAULT_WIDGET_COLOR = '#1f93ff'.freeze

  before_action :set_account
  before_action :validate_account_permissible

  def create
    return render_missing_widget_params if widget_params[:name].blank? || widget_params[:website_url].blank?

    inbox = @account.with_lock { refresh_or_create_inbox }
    render json: serialize(inbox)
  end

  def add_member
    return render json: { error: 'user_id is required' }, status: :unprocessable_entity if member_params[:user_id].blank?

    inbox = web_widget_inbox
    return render json: { error: 'Web widget not found' }, status: :not_found if inbox.blank?

    account_user = @account.account_users.find_by(user_id: member_params[:user_id])
    return render json: { error: 'Account user not found' }, status: :not_found if account_user.blank?

    inbox.inbox_members.find_or_create_by!(user_id: account_user.user_id)
    head :ok
  end

  private

  def set_account
    @account = Account.find(params[:account_id])
  end

  def validate_account_permissible
    return if @platform_app.platform_app_permissibles.find_by(permissible: @account)

    render json: { error: 'Non permissible resource' }, status: :unauthorized
  end

  def refresh_or_create_inbox
    inbox = existing_inbox
    return create_inbox if inbox.blank?

    inbox.channel.update!(channel_attributes)
    inbox
  end

  def existing_inbox
    @account.inboxes.find_by(name: widget_params[:name], channel_type: 'Channel::WebWidget')
  end

  def create_inbox
    channel = @account.web_widgets.create!(channel_attributes.merge(widget_color: widget_color))
    @account.inboxes.create!(name: widget_params[:name], channel: channel)
  end

  def web_widget_inbox
    @account.inboxes.find_by(id: params[:id], channel_type: 'Channel::WebWidget')
  end

  def serialize(inbox)
    {
      id: inbox.id,
      name: inbox.name,
      website_token: inbox.channel.website_token,
      website_url: inbox.channel.website_url
    }
  end

  def channel_attributes
    {
      website_url: widget_params[:website_url],
      welcome_title: widget_params[:welcome_title],
      welcome_tagline: widget_params[:welcome_tagline]
    }.compact
  end

  def widget_color
    widget_params[:widget_color].presence || DEFAULT_WIDGET_COLOR
  end

  def widget_params
    params.permit(:name, :website_url, :widget_color, :welcome_title, :welcome_tagline)
  end

  def member_params
    params.permit(:user_id)
  end

  def render_missing_widget_params
    render json: { error: 'name and website_url are required' }, status: :unprocessable_entity
  end
end
