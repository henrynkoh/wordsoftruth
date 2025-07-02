class AuthController < ApplicationController
  def youtube_callback
    if params[:code].present?
      # Exchange code for tokens
      require 'net/http'
      require 'uri'
      require 'json'
      
      client_id = ENV['GOOGLE_CLIENT_ID'] || Rails.application.credentials.google[:client_id]
      client_secret = ENV['GOOGLE_CLIENT_SECRET'] || Rails.application.credentials.google[:client_secret]
      redirect_uri = "http://localhost:3000/auth/youtube/callback"
      
      uri = URI('https://oauth2.googleapis.com/token')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/x-www-form-urlencoded'
      
      token_params = {
        'client_id' => client_id,
        'client_secret' => client_secret,
        'code' => params[:code],
        'grant_type' => 'authorization_code',
        'redirect_uri' => redirect_uri
      }
      
      request.body = URI.encode_www_form(token_params)
      
      begin
        response = http.request(request)
        
        if response.code == '200'
          data = JSON.parse(response.body)
          
          @access_token = data['access_token']
          @refresh_token = data['refresh_token']
          @success = true
        else
          @error = "Token exchange failed: #{response.body}"
          @success = false
        end
        
      rescue => e
        @error = "Error: #{e.message}"
        @success = false
      end
    else
      @error = "No authorization code received"
      @success = false
    end
    
    render 'youtube_callback'
  end
end