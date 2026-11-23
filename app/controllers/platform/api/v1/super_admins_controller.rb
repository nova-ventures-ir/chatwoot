class Platform::Api::V1::SuperAdminsController < PlatformController
  def login
    email = super_admin_params[:email].to_s.downcase
    nova_user_id = nova_user_attribute(super_admin_params[:custom_attributes])
    return render_invalid if email.blank? || nova_user_id.blank?

    admin = find_or_create_super_admin(email, nova_user_id)
    return if performed?

    @platform_app.platform_app_permissibles.find_or_create_by!(permissible: admin)
    render json: { url: admin.generate_super_admin_sso_link }
  end

  private

  def find_or_create_super_admin(email, nova_user_id)
    existing = User.from_email(email)
    return render_taken_email if existing && !existing.is_a?(SuperAdmin)
    return render_non_permissible if existing && nova_user_attribute(existing.custom_attributes) != nova_user_id

    existing || create_super_admin(email, nova_user_id)
  end

  def create_super_admin(email, nova_user_id)
    admin = SuperAdmin.new(
      name: super_admin_params[:name],
      email: email,
      password: "Aa1!#{SecureRandom.hex(16)}",
      custom_attributes: { 'nova_user_id' => nova_user_id }
    )
    admin.skip_confirmation!
    admin.save!
    admin
  rescue ActiveRecord::RecordNotUnique
    found = SuperAdmin.from_email(email)
    return found if found && nova_user_attribute(found.custom_attributes) == nova_user_id

    found ? render_non_permissible : render_taken_email
  rescue ActiveRecord::RecordInvalid => e
    render json: { message: e.record.errors.full_messages.join(', ') }, status: :unprocessable_entity
    nil
  end

  def super_admin_params
    params.permit(:name, :email, custom_attributes: {})
  end

  def nova_user_attribute(attributes)
    return if attributes.blank?

    attributes.to_h.with_indifferent_access['nova_user_id'].presence&.to_s
  end

  def render_invalid
    render json: { error: 'email and nova_user_id are required' }, status: :unprocessable_entity
  end

  def render_non_permissible
    render json: { error: 'Non permissible resource' }, status: :unauthorized
  end

  def render_taken_email
    user = User.new
    user.errors.add(:email, :taken)
    render json: {
      message: user.errors.full_messages.join(', '),
      attributes: user.errors.attribute_names
    }, status: :unprocessable_entity
    nil
  end
end
