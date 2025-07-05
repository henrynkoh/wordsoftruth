Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
    Rails.application.credentials.dig(:google, :client_id) || ENV['GOOGLE_CLIENT_ID'],
    Rails.application.credentials.dig(:google, :client_secret) || ENV['GOOGLE_CLIENT_SECRET'],
    {
      scope: 'userinfo.email, youtube.upload, youtube',
      access_type: 'offline',
      prompt: 'consent',
      redirect_uri: 'http://localhost:5001/auth/google_oauth2/callback'
    }
end 