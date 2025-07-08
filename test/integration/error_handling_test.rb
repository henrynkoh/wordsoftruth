# frozen_string_literal: true

require "test_helper"

class ErrorHandlingTest < ActionDispatch::IntegrationTest
  def setup
    super
    @user = create_authenticated_user
  end

  test "404 not found error handling" do
    @performance_tracker.track("404 Error Handling") do
      get "/nonexistent-page"
    end

    assert_response :not_found
    assert_includes response.body, "Page not found"
    assert_includes response.body, "404"
  end

  test "500 internal server error handling" do
    # Simulate server error by causing an exception
    ApplicationController.any_instance.stubs(:current_user).raises(StandardError, "Test server error")

    @performance_tracker.track("500 Error Handling") do
      get text_notes_path
    end

    assert_response :internal_server_error
    assert_includes response.body, "Something went wrong"
    assert_includes response.body, "500"
  end

  test "authentication error handling" do
    # Access protected resource without authentication
    session.clear

    @performance_tracker.track("Authentication Error") do
      get text_notes_path
    end

    assert_response :redirect
    assert_redirected_to sign_in_path
    
    follow_redirect!
    assert_includes response.body, "Please sign in"
  end

  test "authorization error handling" do
    # Non-admin user trying to access admin resource
    non_admin_user = create_user_with_oauth("nonadmin@example.com", admin: false)
    sign_in_user(non_admin_user)

    @performance_tracker.track("Authorization Error") do
      get monitoring_path
    end

    assert_response :redirect
    assert_redirected_to root_path
    
    follow_redirect!
    assert_includes response.body, "Access denied"
  end

  test "validation error handling in text notes" do
    @performance_tracker.track("Validation Error Handling") do
      post text_notes_path, params: { 
        text_note: { 
          title: "", # Invalid: blank title
          content: "x" * 50001, # Invalid: too long
          note_type: "invalid_type" # Invalid: not in allowed values
        }
      }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "Title can&#x27;t be blank"
    assert_includes response.body, "Content is too long"
    assert_includes response.body, "Note type is not included"
  end

  test "database connection error handling" do
    # Simulate database connection failure
    ActiveRecord::Base.connection_pool.disconnect!

    @performance_tracker.track("Database Error Handling") do
      get text_notes_path
    end

    # Should gracefully handle database errors
    assert_response :internal_server_error
    assert_includes response.body, "Database temporarily unavailable"

    # Restore connection for subsequent tests
    ActiveRecord::Base.establish_connection
  end

  test "file upload error handling" do
    # Test with oversized file
    large_file = fixture_file_upload("files/large_file.txt", "text/plain")
    
    @performance_tracker.track("File Upload Error") do
      post upload_file_path, params: { file: large_file }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "File size exceeds limit"
  end

  test "malicious file upload error handling" do
    # Test with potentially malicious file
    malicious_file = fixture_file_upload("files/malicious.exe", "application/octet-stream")
    
    @performance_tracker.track("Malicious File Handling") do
      post upload_file_path, params: { file: malicious_file }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "Invalid file type"
  end

  test "rate limit error handling" do
    # Exceed rate limit
    60.times do |i|
      post text_notes_path, params: { 
        text_note: { 
          title: "Rate limit test #{i}",
          content: "Test content",
          note_type: "reflection"
        }
      }
    end

    # Next request should be rate limited
    @performance_tracker.track("Rate Limit Error") do
      post text_notes_path, params: { 
        text_note: { 
          title: "Rate limited",
          content: "Test content",
          note_type: "reflection"
        }
      }
    end

    assert_response :too_many_requests
    assert_includes response.body, "Rate limit exceeded"
  end

  test "external service timeout error handling" do
    # Simulate external service timeout
    sermon_url = "https://timeout-example.com/sermon"
    stub_request(:get, sermon_url).to_timeout

    @performance_tracker.track("Timeout Error Handling") do
      post sermon_automation_index_path, params: { 
        sermon: { source_url: sermon_url }
      }
    end

    assert_response :redirect
    follow_redirect!
    assert_includes response.body, "Request timed out"
  end

  test "external service unavailable error handling" do
    # Simulate external service returning 503
    sermon_url = "https://unavailable-example.com/sermon"
    stub_request(:get, sermon_url).to_return(status: 503, body: "Service Unavailable")

    @performance_tracker.track("Service Unavailable Handling") do
      post sermon_automation_index_path, params: { 
        sermon: { source_url: sermon_url }
      }
    end

    assert_response :redirect
    follow_redirect!
    assert_includes response.body, "External service temporarily unavailable"
  end

  test "JSON parsing error handling" do
    # Send malformed JSON to API endpoint
    @performance_tracker.track("JSON Parse Error") do
      post api_text_notes_path, 
        params: "{ invalid json }",
        headers: { 
          "Content-Type" => "application/json",
          "Accept" => "application/json"
        }
    end

    assert_response :bad_request
    json_response = JSON.parse(response.body)
    assert_equal "Invalid JSON format", json_response["error"]
  end

  test "CSRF token missing error handling" do
    # Disable CSRF protection temporarily to test this scenario
    ActionController::Base.skip_before_action :verify_authenticity_token

    @performance_tracker.track("CSRF Error Handling") do
      post text_notes_path, params: { 
        text_note: { 
          title: "CSRF test",
          content: "Test content",
          note_type: "reflection"
        }
      }
    end

    # Re-enable CSRF protection
    ActionController::Base.before_action :verify_authenticity_token

    # Should handle missing CSRF token gracefully
    # (specific behavior depends on implementation)
    assert_response_includes "authenticity token"
  end

  test "session expiry error handling" do
    # Set up expired session
    travel 25.hours do
      @performance_tracker.track("Session Expiry Handling") do
        get text_notes_path
      end
    end

    assert_response :redirect
    assert_redirected_to sign_in_path
    
    follow_redirect!
    assert_includes response.body, "session has expired"
  end

  test "memory limit error handling" do
    # Test memory-intensive operation
    large_text_notes = Array.new(1000) do |i|
      {
        title: "Large note #{i}",
        content: "x" * 10000, # 10KB content each
        note_type: "reflection"
      }
    end

    @performance_tracker.track("Memory Limit Handling") do
      post bulk_create_text_notes_path, params: { text_notes: large_text_notes }
    end

    # Should handle memory limits gracefully
    assert_response_in [413, 422] # Payload too large or unprocessable entity
    if response.status == 422
      assert_includes response.body, "Request too large"
    end
  end

  test "concurrent request error handling" do
    # Test handling of concurrent requests to same resource
    text_note = create_text_note_for_user(@user)

    threads = 5.times.map do |i|
      Thread.new do
        patch text_note_path(text_note), params: { 
          text_note: { title: "Concurrent update #{i}" }
        }
      end
    end

    @performance_tracker.track("Concurrent Request Handling") do
      threads.each(&:join)
    end

    # Should handle concurrent updates gracefully
    text_note.reload
    assert_includes text_note.title, "Concurrent update"
  end

  test "SSL/TLS error handling" do
    # Test handling of SSL certificate errors (simulated)
    sermon_url = "https://invalid-ssl.example.com/sermon"
    stub_request(:get, sermon_url).to_raise(OpenSSL::SSL::SSLError.new("SSL Error"))

    @performance_tracker.track("SSL Error Handling") do
      post sermon_automation_index_path, params: { 
        sermon: { source_url: sermon_url }
      }
    end

    assert_response :redirect
    follow_redirect!
    assert_includes response.body, "SSL certificate error"
  end

  test "disk space error handling" do
    # Simulate disk space error during file operations
    File.stubs(:write).raises(Errno::ENOSPC, "No space left on device")

    @performance_tracker.track("Disk Space Error") do
      post text_notes_path, params: { 
        text_note: { 
          title: "Disk space test",
          content: "Test content",
          note_type: "reflection"
        }
      }
    end

    assert_response :internal_server_error
    assert_includes response.body, "Storage temporarily unavailable"
  end

  test "job queue failure error handling" do
    # Simulate job queue failure
    Sidekiq::Client.stubs(:push).raises(Redis::ConnectionError, "Redis connection failed")

    @performance_tracker.track("Job Queue Error") do
      post text_notes_path, params: { 
        text_note: { 
          title: "Job queue test",
          content: "Test content",
          note_type: "reflection"
        }
      }
    end

    # Should create the text note but show warning about background processing
    assert_response :redirect
    follow_redirect!
    assert_includes response.body, "created successfully"
    assert_includes response.body, "background processing temporarily unavailable"
  end

  test "error logging and monitoring" do
    # Test that errors are properly logged
    assert_logged(/ERROR.*StandardError.*Test error/) do
      ApplicationController.any_instance.stubs(:current_user).raises(StandardError, "Test error")
      
      @performance_tracker.track("Error Logging") do
        get text_notes_path
      end
    end

    assert_response :internal_server_error
  end

  test "graceful degradation during partial failures" do
    # Test system behavior when some components fail
    # Simulate cache failure but database works
    Rails.cache.stubs(:read).raises(Redis::ConnectionError, "Cache unavailable")
    Rails.cache.stubs(:write).raises(Redis::ConnectionError, "Cache unavailable")

    @performance_tracker.track("Graceful Degradation") do
      get text_notes_path
    end

    # Should still work without cache
    assert_response :success
    assert_includes response.body, "Text Notes"
  end

  test "error recovery and retry mechanisms" do
    # Test automatic retry for transient failures
    call_count = 0
    SermonCrawlerService.any_instance.stubs(:crawl).returns(
      proc { 
        call_count += 1
        if call_count == 1
          raise Net::TimeoutError, "Temporary timeout"
        else
          OpenStruct.new(success?: true, sermon: create_valid_sermon)
        end
      }.call
    )

    @performance_tracker.track("Error Recovery") do
      post sermon_automation_index_path, params: { 
        sermon: { source_url: "https://example.com/sermon" }
      }
    end

    assert_response :redirect
    follow_redirect!
    assert_includes response.body, "Sermon processing started"
    assert_equal 2, call_count # Should have retried once
  end

  private

  def create_authenticated_user
    oauth_data = {
      "provider" => "google_oauth2",
      "uid" => "123456789",
      "info" => {
        "email" => "test@example.com",
        "name" => "Test User"
      }
    }
    
    user = User.find_or_create_by_omniauth(oauth_data)
    sign_in_user(user)
    user
  end

  def create_user_with_oauth(email, admin: false)
    oauth_data = {
      "provider" => "google_oauth2",
      "uid" => SecureRandom.hex(8),
      "info" => {
        "email" => email,
        "name" => "Test User"
      }
    }
    
    user = User.find_or_create_by_omniauth(oauth_data)
    user.update!(admin: admin)
    user
  end

  def sign_in_user(user)
    session[:user_id] = user.id
    session[:signed_in_at] = Time.current
  end

  def create_text_note_for_user(user, attributes = {})
    default_attributes = {
      title: "Test Note",
      content: "Test content",
      note_type: "reflection",
      user: user
    }

    TextNote.create!(default_attributes.merge(attributes))
  end

  def assert_response_in(status_codes)
    assert_includes status_codes, response.status,
      "Expected response status to be one of #{status_codes}, but was #{response.status}"
  end

  def sign_in_path
    "/auth/google_oauth2"
  end

  def monitoring_path
    "/monitoring"
  end

  def upload_file_path
    "/files/upload"
  end

  def sermon_automation_index_path
    "/"
  end

  def api_text_notes_path
    "/api/text_notes"
  end

  def bulk_create_text_notes_path
    "/text_notes/bulk_create"
  end
end