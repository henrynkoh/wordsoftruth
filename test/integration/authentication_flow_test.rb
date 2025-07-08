# frozen_string_literal: true

require "test_helper"

class AuthenticationFlowTest < ActionDispatch::IntegrationTest
  def setup
    super
    @user_data = {
      "provider" => "google_oauth2",
      "uid" => "123456789",
      "info" => {
        "email" => "test@example.com",
        "name" => "Test User",
        "image" => "https://example.com/avatar.jpg"
      },
      "credentials" => {
        "token" => "mock_access_token",
        "refresh_token" => "mock_refresh_token",
        "expires_at" => 1.hour.from_now.to_i
      }
    }
  end

  test "successful OAuth authentication creates new user" do
    assert_difference "User.count", 1 do
      @performance_tracker.track("OAuth Authentication") do
        simulate_oauth_callback(@user_data)
      end
    end

    assert_response :redirect
    assert_redirected_to root_path
    
    user = User.last
    assert_equal @user_data["info"]["email"], user.email
    assert_equal @user_data["info"]["name"], user.name
    assert_equal @user_data["uid"], user.uid
    assert_equal @user_data["provider"], user.provider
    assert user.active?
    assert_not user.admin?
    
    follow_redirect!
    assert_response :success
    assert_includes response.body, "Successfully signed in"
  end

  test "OAuth authentication updates existing user" do
    user = create_user(@user_data)
    updated_name = "Updated Test User"
    @user_data["info"]["name"] = updated_name

    assert_no_difference "User.count" do
      @performance_tracker.track("OAuth Update User") do
        simulate_oauth_callback(@user_data)
      end
    end

    assert_response :redirect
    user.reload
    assert_equal updated_name, user.name
    assert user.last_sign_in_at > 1.minute.ago
  end

  test "OAuth authentication with invalid data fails gracefully" do
    invalid_data = @user_data.dup
    invalid_data["info"]["email"] = "invalid-email"

    assert_no_difference "User.count" do
      simulate_oauth_callback(invalid_data)
    end

    assert_response :redirect
    assert_redirected_to root_path
    follow_redirect!
    assert_includes response.body, "Authentication failed"
  end

  test "authentication protects restricted pages" do
    @performance_tracker.track("Protected Page Access") do
      get text_notes_path
    end

    assert_response :redirect
    assert_redirected_to sign_in_path
    
    follow_redirect!
    assert_includes response.body, "Please sign in"
  end

  test "authenticated user can access protected pages" do
    user = create_and_sign_in_user

    @performance_tracker.track("Authenticated Access") do
      get text_notes_path
    end

    assert_response :success
    assert_includes response.body, "Text Notes"
  end

  test "session expires after configured timeout" do
    user = create_and_sign_in_user
    
    # Simulate session timeout
    travel 25.hours do
      @performance_tracker.track("Session Timeout Check") do
        get text_notes_path
      end
    end

    assert_response :redirect
    assert_redirected_to sign_in_path
    follow_redirect!
    assert_includes response.body, "session has expired"
  end

  test "user can sign out successfully" do
    user = create_and_sign_in_user
    
    @performance_tracker.track("Sign Out") do
      delete sign_out_path
    end

    assert_response :redirect
    assert_redirected_to root_path
    
    follow_redirect!
    assert_includes response.body, "Successfully signed out"
    
    # Verify user can't access protected pages
    get text_notes_path
    assert_response :redirect
    assert_redirected_to sign_in_path
  end

  test "inactive user cannot access protected pages" do
    user = create_user(@user_data)
    user.update!(active: false)
    
    simulate_oauth_callback(@user_data)
    
    assert_response :redirect
    assert_redirected_to sign_in_path
    follow_redirect!
    assert_includes response.body, "account has been deactivated"
  end

  test "admin user can access admin pages" do
    user = create_and_sign_in_user(admin: true)
    
    @performance_tracker.track("Admin Access") do
      get monitoring_path
    end

    assert_response :success
  end

  test "non-admin user cannot access admin pages" do
    user = create_and_sign_in_user(admin: false)
    
    @performance_tracker.track("Non-Admin Access Denial") do
      get monitoring_path
    end

    assert_response :redirect
    assert_redirected_to root_path
    follow_redirect!
    assert_includes response.body, "Access denied"
  end

  test "YouTube authentication flow" do
    user = create_and_sign_in_user
    
    # Mock YouTube OAuth data
    youtube_data = @user_data.dup
    youtube_data["credentials"]["scope"] = "userinfo.email youtube.upload"
    
    @performance_tracker.track("YouTube Authentication") do
      simulate_oauth_callback(youtube_data)
    end

    user.reload
    assert user.youtube_authenticated?
    assert_not user.youtube_token_expired?
  end

  test "expired YouTube token redirects to re-authentication" do
    user = create_and_sign_in_user
    user.update!(
      youtube_access_token: "expired_token",
      youtube_refresh_token: "refresh_token",
      youtube_token_expires_at: 1.hour.ago
    )

    @performance_tracker.track("Expired Token Handling") do
      get youtube_automation_path
    end

    assert_response :redirect
    assert_match /auth\/google_oauth2/, response.location
  end

  test "authentication rate limiting" do
    # Simulate multiple failed authentication attempts
    15.times do |i|
      invalid_data = @user_data.dup
      invalid_data["uid"] = "invalid_#{i}"
      
      post "/auth/google_oauth2/callback", params: { error: "access_denied" }
    end

    # Next attempt should be rate limited
    post "/auth/google_oauth2/callback", params: { error: "access_denied" }
    
    assert_response :too_many_requests
    assert_includes response.body, "Rate limit exceeded"
  end

  test "concurrent authentication requests" do
    assert_concurrent_performance(5, 10.seconds) do |user_index|
      user_data = @user_data.dup
      user_data["uid"] = "concurrent_user_#{user_index}"
      user_data["info"]["email"] = "concurrent_#{user_index}@example.com"
      
      simulate_oauth_callback(user_data)
    end

    assert_equal 5, User.where("email LIKE ?", "concurrent_%").count
  end

  test "authentication with malicious input" do
    malicious_data = @user_data.dup
    malicious_data["info"]["name"] = "<script>alert('xss')</script>"
    malicious_data["info"]["email"] = "test';DROP TABLE users;--@example.com"

    assert_difference "User.count", 1 do
      simulate_oauth_callback(malicious_data)
    end

    user = User.last
    assert_sanitized_content(user.name)
    assert_not_includes user.name, "<script>"
    assert_not_includes user.email, "DROP TABLE"
  end

  test "authentication preserves redirect path" do
    intended_path = "/text_notes/new"
    
    get intended_path
    assert_response :redirect
    assert_redirected_to sign_in_path
    
    user = create_user(@user_data)
    simulate_oauth_callback(@user_data)
    
    assert_response :redirect
    assert_redirected_to intended_path
  end

  test "authentication performance meets requirements" do
    assert_performance_within(IntegrationTestHelper::PERFORMANCE_CONFIG[:api_response]) do
      simulate_oauth_callback(@user_data)
    end
  end

  test "authentication logging captures security events" do
    assert_logged(/Auth Event: oauth_callback/) do
      simulate_oauth_callback(@user_data)
    end
  end

  private

  def create_user(oauth_data)
    User.find_or_create_by_omniauth(oauth_data)
  end

  def create_and_sign_in_user(admin: false)
    user = create_user(@user_data)
    user.update!(admin: admin) if admin
    simulate_oauth_callback(@user_data)
    user
  end

  def simulate_oauth_callback(oauth_data)
    # Mock OmniAuth data
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(oauth_data)
    
    post "/auth/google_oauth2/callback"
    
    OmniAuth.config.test_mode = false
  end

  def sign_in_path
    "/auth/google_oauth2"
  end

  def sign_out_path
    "/auth/signout"
  end

  def monitoring_path
    "/monitoring"
  end

  def youtube_automation_path
    "/youtube_automation"
  end
end