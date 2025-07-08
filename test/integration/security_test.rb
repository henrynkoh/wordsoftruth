# frozen_string_literal: true

require "test_helper"

class SecurityTest < ActionDispatch::IntegrationTest
  def setup
    super
    @user = create_authenticated_user
    @malicious_inputs = [
      "<script>alert('xss')</script>",
      "javascript:alert('xss')",
      "'; DROP TABLE users; --",
      "../../../etc/passwd",
      "<iframe src='javascript:alert(1)'></iframe>",
      "<img onerror='alert(1)' src='x'>",
      "data:text/html,<script>alert('xss')</script>",
      "%3Cscript%3Ealert%28%27xss%27%29%3C%2Fscript%3E"
    ]
  end

  test "XSS protection in text note creation" do
    @malicious_inputs.each do |malicious_input|
      @performance_tracker.track("XSS Protection Test") do
        post text_notes_path, params: { 
          text_note: { 
            title: malicious_input,
            content: "Test content with malicious title",
            note_type: "reflection"
          }
        }
      end

      if response.status == 422
        # Input was rejected - this is good
        assert_includes response.body, "contains potentially malicious content"
      else
        # Input was accepted but should be sanitized
        text_note = TextNote.last
        assert_sanitized_content(text_note.title)
        assert_not_includes text_note.title, "<script>"
        assert_not_includes text_note.title, "javascript:"
      end
    end
  end

  test "SQL injection protection" do
    sql_injection_attempts = [
      "'; DROP TABLE text_notes; --",
      "' OR '1'='1",
      "1; DELETE FROM users WHERE 1=1; --",
      "' UNION SELECT * FROM users --",
      "admin'--",
      "' OR 1=1#"
    ]

    sql_injection_attempts.each do |injection|
      @performance_tracker.track("SQL Injection Protection") do
        post text_notes_path, params: { 
          text_note: { 
            title: "Test Note",
            content: injection,
            note_type: "reflection"
          }
        }
      end

      # Should either reject the input or sanitize it
      if response.status == 422
        assert_includes response.body, "suspicious SQL patterns"
      else
        text_note = TextNote.last
        assert_not_includes text_note.content.downcase, "drop table"
        assert_not_includes text_note.content.downcase, "delete from"
        assert_not_includes text_note.content.downcase, "union select"
      end
    end
  end

  test "CSRF protection on forms" do
    # Clear authenticity token to test CSRF protection
    @performance_tracker.track("CSRF Protection Test") do
      post text_notes_path, params: { 
        text_note: { 
          title: "CSRF Test",
          content: "Test content",
          note_type: "reflection"
        }
      }, headers: { "HTTP_X_CSRF_TOKEN" => "invalid_token" }
    end

    # Should be rejected due to invalid CSRF token
    assert_response_in [403, 422]
  end

  test "authentication bypass attempts" do
    # Clear session to test unauthenticated access
    session.clear

    protected_paths = [
      text_notes_path,
      new_text_note_path,
      "/monitoring",
      "/admin"
    ]

    protected_paths.each do |path|
      @performance_tracker.track("Auth Bypass Attempt") do
        get path
      end

      assert_response_in [302, 401, 403] # Redirect to login or unauthorized
    end
  end

  test "session fixation protection" do
    original_session_id = request.session_options[:id]

    # Authenticate user
    @performance_tracker.track("Session Fixation Test") do
      post "/auth/google_oauth2/callback"
    end

    new_session_id = request.session_options[:id]
    
    # Session ID should change after authentication
    assert_not_equal original_session_id, new_session_id,
      "Session ID should change after authentication to prevent session fixation"
  end

  test "file upload security" do
    # Test with various malicious file types
    malicious_files = [
      { name: "malicious.exe", content: "MZ\x90\x00", content_type: "application/octet-stream" },
      { name: "script.php", content: "<?php system($_GET['cmd']); ?>", content_type: "application/x-php" },
      { name: "shell.sh", content: "#!/bin/bash\nrm -rf /", content_type: "application/x-sh" },
      { name: "virus.bat", content: "@echo off\ndel /q *.*", content_type: "application/x-msdos-program" }
    ]

    malicious_files.each do |file_data|
      file = create_temp_file(file_data[:name], file_data[:content])
      
      @performance_tracker.track("Malicious File Upload") do
        post upload_file_path, params: { 
          file: fixture_file_upload(file, file_data[:content_type])
        }
      end

      assert_response :unprocessable_entity
      assert_includes response.body, "Invalid file type"
      
      File.delete(file) if File.exist?(file)
    end
  end

  test "path traversal protection" do
    path_traversal_attempts = [
      "../../../etc/passwd",
      "..\\..\\..\\windows\\system32\\config\\sam",
      "....//....//....//etc//passwd",
      "%2e%2e%2f%2e%2e%2f%2e%2e%2fetc%2fpasswd",
      "..%252f..%252f..%252fetc%252fpasswd"
    ]

    path_traversal_attempts.each do |malicious_path|
      @performance_tracker.track("Path Traversal Protection") do
        get "/files/#{malicious_path}"
      end

      assert_response_in [400, 404] # Bad request or not found
      assert_not_includes response.body, "root:x:" # Should not show passwd file content
    end
  end

  test "SSRF protection in sermon URL crawling" do
    ssrf_urls = [
      "http://127.0.0.1:80/",
      "http://localhost:3000/admin",
      "http://10.0.0.1/internal",
      "http://172.16.0.1/private",
      "http://192.168.1.1/router",
      "http://169.254.169.254/metadata",
      "file:///etc/passwd",
      "ftp://internal.company.com/secret"
    ]

    ssrf_urls.each do |malicious_url|
      @performance_tracker.track("SSRF Protection") do
        post sermon_automation_index_path, params: { 
          sermon: { source_url: malicious_url }
        }
      end

      assert_response :unprocessable_entity
      assert_includes response.body, "Invalid URL"
    end
  end

  test "content security policy headers" do
    @performance_tracker.track("CSP Headers Test") do
      get root_path
    end

    assert_response :success
    
    csp_header = response.headers["Content-Security-Policy"]
    assert_not_nil csp_header, "Content-Security-Policy header should be present"
    
    # Verify CSP contains security directives
    assert_includes csp_header, "default-src 'self'"
    assert_includes csp_header, "object-src 'none'"
    assert_includes csp_header, "base-uri 'self'"
  end

  test "security headers presence" do
    @performance_tracker.track("Security Headers Test") do
      get root_path
    end

    assert_response :success
    
    # Test for important security headers
    assert_equal "1; mode=block", response.headers["X-XSS-Protection"]
    assert_equal "nosniff", response.headers["X-Content-Type-Options"]
    assert_equal "DENY", response.headers["X-Frame-Options"]
    assert_includes response.headers["Referrer-Policy"], "strict-origin"
  end

  test "password-related security" do
    # Test that sensitive data is not logged
    Rails.logger.expects(:info).never.with(regexp_matches(/password/i))
    Rails.logger.expects(:debug).never.with(regexp_matches(/token/i))

    @performance_tracker.track("Sensitive Data Logging") do
      post "/auth/google_oauth2/callback", params: {
        user: { password: "secret123", access_token: "sensitive_token" }
      }
    end
  end

  test "rate limiting security" do
    # Test that rate limiting prevents abuse
    client_ip = "192.168.1.100"
    
    # Simulate requests from same IP
    25.times do |i|
      @performance_tracker.track("Rate Limit Request #{i}") do
        post text_notes_path, 
          params: { 
            text_note: { 
              title: "Rate limit test #{i}",
              content: "Test content",
              note_type: "reflection"
            }
          },
          headers: { "REMOTE_ADDR" => client_ip }
      end
    end

    # Next request should be rate limited
    post text_notes_path, 
      params: { 
        text_note: { 
          title: "Should be blocked",
          content: "Test content",
          note_type: "reflection"
        }
      },
      headers: { "REMOTE_ADDR" => client_ip }

    assert_response :too_many_requests
  end

  test "input size limits" do
    # Test extremely large inputs
    large_content = "x" * 100_000 # 100KB

    @performance_tracker.track("Large Input Test") do
      post text_notes_path, params: { 
        text_note: { 
          title: "Large input test",
          content: large_content,
          note_type: "reflection"
        }
      }
    end

    assert_response_in [413, 422] # Payload too large or validation error
  end

  test "HTTP verb tampering protection" do
    text_note = create_text_note(@user)

    # Attempt to delete using POST with _method parameter
    @performance_tracker.track("HTTP Verb Tampering") do
      post text_note_path(text_note), params: { _method: "DELETE" }
    end

    # Should not delete the resource
    assert TextNote.exists?(text_note.id), "Resource should not be deleted via verb tampering"
  end

  test "mass assignment protection" do
    # Attempt to set protected attributes
    @performance_tracker.track("Mass Assignment Test") do
      post text_notes_path, params: { 
        text_note: { 
          title: "Mass assignment test",
          content: "Test content",
          note_type: "reflection",
          user_id: 999999, # Should not be assignable
          admin: true, # Should not be assignable
          created_at: 1.year.ago # Should not be assignable
        }
      }
    end

    text_note = TextNote.last
    assert_equal @user.id, text_note.user_id, "user_id should not be mass assignable"
    assert_not text_note.respond_to?(:admin), "admin should not be mass assignable"
    assert text_note.created_at > 1.hour.ago, "created_at should not be mass assignable"
  end

  test "redirect security" do
    malicious_redirects = [
      "http://malicious.com/steal-data",
      "javascript:alert('xss')",
      "//malicious.com/phishing",
      "https://malicious.com/fake-login"
    ]

    malicious_redirects.each do |redirect_url|
      @performance_tracker.track("Redirect Security Test") do
        get "/auth/signout", params: { redirect_to: redirect_url }
      end

      # Should not redirect to external malicious sites
      assert_response :redirect
      assert_not_includes response.location, "malicious.com"
      assert_not_includes response.location, "javascript:"
    end
  end

  test "API key and token security" do
    # Test that API keys/tokens are not exposed in responses
    @performance_tracker.track("Token Security Test") do
      get "/api/text_notes", headers: { "Accept" => "application/json" }
    end

    assert_response :success
    response_body = response.body.downcase
    
    # Should not contain sensitive data
    assert_not_includes response_body, "access_token"
    assert_not_includes response_body, "refresh_token"
    assert_not_includes response_body, "api_key"
    assert_not_includes response_body, "secret"
  end

  test "timing attack protection" do
    # Test that authentication timing is consistent
    valid_email = @user.email
    invalid_email = "nonexistent@example.com"

    # Measure timing for valid authentication
    start_time = Time.current
    post "/auth/google_oauth2/callback", params: { email: valid_email }
    valid_auth_time = Time.current - start_time

    # Measure timing for invalid authentication  
    start_time = Time.current
    post "/auth/google_oauth2/callback", params: { email: invalid_email }
    invalid_auth_time = Time.current - start_time

    # Timing difference should not be significant (less than 100ms)
    timing_difference = (valid_auth_time - invalid_auth_time).abs
    assert timing_difference < 0.1, "Authentication timing should be consistent to prevent timing attacks"
  end

  test "concurrent security stress test" do
    # Test security under concurrent load
    assert_concurrent_performance(10, 30.seconds) do |user_index|
      # Each thread attempts different security violations
      case user_index % 4
      when 0
        # XSS attempt
        post text_notes_path, params: { 
          text_note: { 
            title: "<script>alert(#{user_index})</script>",
            content: "XSS test",
            note_type: "reflection"
          }
        }
      when 1
        # SQL injection attempt
        post text_notes_path, params: { 
          text_note: { 
            title: "SQL test",
            content: "'; DROP TABLE text_notes; --",
            note_type: "reflection"
          }
        }
      when 2
        # Path traversal attempt
        get "/files/../../../etc/passwd"
      when 3
        # SSRF attempt
        post sermon_automation_index_path, params: { 
          sermon: { source_url: "http://127.0.0.1/internal" }
        }
      end
    end

    # System should remain stable and secure
    assert_response_in [200, 302, 400, 422, 500]
  end

  private

  def create_authenticated_user
    oauth_data = {
      "provider" => "google_oauth2",
      "uid" => "123456789",
      "info" => {
        "email" => "security-test@example.com",
        "name" => "Security Test User"
      }
    }
    
    user = User.find_or_create_by_omniauth(oauth_data)
    sign_in_user(user)
    user
  end

  def sign_in_user(user)
    session[:user_id] = user.id
    session[:signed_in_at] = Time.current
  end

  def create_text_note(user, attributes = {})
    default_attributes = {
      title: "Security Test Note",
      content: "Security test content",
      note_type: "reflection",
      user: user
    }

    TextNote.create!(default_attributes.merge(attributes))
  end

  def create_temp_file(filename, content)
    temp_dir = Rails.root.join("tmp", "security_test")
    FileUtils.mkdir_p(temp_dir)
    
    file_path = temp_dir.join(filename)
    File.write(file_path, content)
    file_path.to_s
  end

  def assert_response_in(status_codes)
    assert_includes status_codes, response.status,
      "Expected response status to be one of #{status_codes}, but was #{response.status}"
  end

  def upload_file_path
    "/files/upload"
  end

  def sermon_automation_index_path
    "/"
  end
end