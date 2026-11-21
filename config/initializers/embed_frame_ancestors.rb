# Lets the Nova panel iframe Chatwoot. Space-separated origins.
# Empty keeps Rails' default X-Frame-Options: SAMEORIGIN.
class EmbedFrameAncestors
  def initialize(app)
    @app = app
    @frame_ancestors = ENV.fetch('EMBED_FRAME_ANCESTORS', '').split(/[\s,]+/).compact_blank.join(' ')
  end

  def call(env)
    status, headers, body = @app.call(env)
    if @frame_ancestors.present?
      headers.delete('X-Frame-Options')
      headers['Content-Security-Policy'] = "frame-ancestors #{@frame_ancestors}"
    end
    [status, headers, body]
  end
end

Rails.application.config.middleware.use EmbedFrameAncestors
