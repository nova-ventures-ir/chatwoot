# Lets the Nova panel iframe Chatwoot. Space-separated origins.
# Empty keeps Rails' default X-Frame-Options: SAMEORIGIN.
# The public website widget keeps the frame policy from WidgetsController so a
# landing page can embed it. This middleware must not replace that policy.
class EmbedFrameAncestors
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)
    return [status, headers, body] if widget_request?(env)

    ancestors = frame_ancestors
    if ancestors.present?
      headers.delete('X-Frame-Options')
      headers['Content-Security-Policy'] = "frame-ancestors #{ancestors}"
    end
    [status, headers, body]
  end

  private

  def widget_request?(env)
    path = env['PATH_INFO'].to_s
    path == '/widget' || path.start_with?('/widget/')
  end

  def frame_ancestors
    ENV.fetch('EMBED_FRAME_ANCESTORS', '').split(/[\s,]+/).compact_blank.join(' ')
  end
end

Rails.application.config.middleware.use EmbedFrameAncestors
