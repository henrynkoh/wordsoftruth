# frozen_string_literal: true

require "test_helper"

class ApiEndpointsTest < ActionDispatch::IntegrationTest
  def setup
    super
    @user = create_authenticated_user
    @headers = {
      "Content-Type" => "application/json",
      "Accept" => "application/json"
    }
  end

  test "API text notes index endpoint" do
    create_sample_text_notes(@user, 5)

    @performance_tracker.track("API Text Notes Index") do
      get "/api/text_notes", headers: @headers
    end

    assert_response :success
    assert_equal "application/json", response.content_type

    json_data = JSON.parse(response.body)
    assert json_data.key?("text_notes")
    assert_equal 5, json_data["text_notes"].count
    assert json_data.key?("meta")
    assert json_data["meta"].key?("total_count")
  end

  test "API text notes show endpoint" do
    text_note = create_text_note(@user)

    @performance_tracker.track("API Text Note Show") do
      get "/api/text_notes/#{text_note.id}", headers: @headers
    end

    assert_response :success
    json_data = JSON.parse(response.body)
    
    assert_equal text_note.id, json_data["text_note"]["id"]
    assert_equal text_note.title, json_data["text_note"]["title"]
    assert_equal text_note.content, json_data["text_note"]["content"]
    assert_equal text_note.theme, json_data["text_note"]["theme"]
  end

  test "API text notes create endpoint" do
    text_note_params = {
      title: "API Test Note",
      content: "This is a test note created via API",
      note_type: "reflection",
      visibility: "private"
    }

    assert_difference "TextNote.count", 1 do
      @performance_tracker.track("API Text Note Create") do
        post "/api/text_notes", 
          params: { text_note: text_note_params }.to_json,
          headers: @headers
      end
    end

    assert_response :created
    json_data = JSON.parse(response.body)
    
    assert_equal text_note_params[:title], json_data["text_note"]["title"]
    assert_equal text_note_params[:content], json_data["text_note"]["content"]
    assert_equal @user.id, json_data["text_note"]["user_id"]
  end

  test "API text notes update endpoint" do
    text_note = create_text_note(@user)
    update_params = { title: "Updated via API" }

    @performance_tracker.track("API Text Note Update") do
      patch "/api/text_notes/#{text_note.id}",
        params: { text_note: update_params }.to_json,
        headers: @headers
    end

    assert_response :success
    json_data = JSON.parse(response.body)
    
    assert_equal update_params[:title], json_data["text_note"]["title"]
    
    text_note.reload
    assert_equal update_params[:title], text_note.title
  end

  test "API text notes delete endpoint" do
    text_note = create_text_note(@user)

    assert_difference "TextNote.count", -1 do
      @performance_tracker.track("API Text Note Delete") do
        delete "/api/text_notes/#{text_note.id}", headers: @headers
      end
    end

    assert_response :no_content
    assert_empty response.body
  end

  test "API sermons index endpoint" do
    create_sample_sermons(@user, 3)

    @performance_tracker.track("API Sermons Index") do
      get "/api/sermons", headers: @headers
    end

    assert_response :success
    json_data = JSON.parse(response.body)
    
    assert json_data.key?("sermons")
    assert_equal 3, json_data["sermons"].count
    assert json_data["sermons"].first.key?("title")
    assert json_data["sermons"].first.key?("church")
    assert json_data["sermons"].first.key?("pastor")
  end

  test "API sermon show endpoint" do
    sermon = create_sermon(@user)

    @performance_tracker.track("API Sermon Show") do
      get "/api/sermons/#{sermon.id}", headers: @headers
    end

    assert_response :success
    json_data = JSON.parse(response.body)
    
    assert_equal sermon.id, json_data["sermon"]["id"]
    assert_equal sermon.title, json_data["sermon"]["title"]
    assert_equal sermon.church, json_data["sermon"]["church"]
    assert_equal sermon.scripture, json_data["sermon"]["scripture"]
  end

  test "API sermon creation endpoint" do
    sermon_params = {
      source_url: "https://api-test.com/sermon",
      title: "API Created Sermon",
      church: "API Test Church",
      pastor: "API Test Pastor",
      scripture: "API 1:1",
      interpretation: "API test interpretation content",
      action_points: "API test action points",
      denomination: "API Test",
      sermon_date: 1.week.ago.iso8601,
      audience_count: 100
    }

    assert_difference "Sermon.count", 1 do
      @performance_tracker.track("API Sermon Create") do
        post "/api/sermons",
          params: { sermon: sermon_params }.to_json,
          headers: @headers
      end
    end

    assert_response :created
    json_data = JSON.parse(response.body)
    
    assert_equal sermon_params[:title], json_data["sermon"]["title"]
    assert_equal sermon_params[:church], json_data["sermon"]["church"]
  end

  test "API video generation endpoint" do
    sermon = create_sermon(@user)
    video_params = {
      script: "API test video script content",
      theme: "faith"
    }

    @performance_tracker.track("API Video Generation") do
      post "/api/sermons/#{sermon.id}/generate_video",
        params: { video: video_params }.to_json,
        headers: @headers
    end

    assert_response :accepted
    json_data = JSON.parse(response.body)
    
    assert json_data.key?("job_id")
    assert_equal "Video generation started", json_data["message"]
    assert json_data.key?("status_url")
  end

  test "API video status endpoint" do
    sermon = create_sermon(@user)
    video = create_video(sermon, status: "processing")

    @performance_tracker.track("API Video Status") do
      get "/api/videos/#{video.id}/status", headers: @headers
    end

    assert_response :success
    json_data = JSON.parse(response.body)
    
    assert_equal "processing", json_data["status"]
    assert json_data.key?("progress_percentage")
    assert json_data.key?("current_step")
  end

  test "API pagination" do
    create_sample_text_notes(@user, 25)

    @performance_tracker.track("API Pagination") do
      get "/api/text_notes?page=2&per_page=10", headers: @headers
    end

    assert_response :success
    json_data = JSON.parse(response.body)
    
    assert_equal 10, json_data["text_notes"].count
    assert_equal 2, json_data["meta"]["current_page"]
    assert_equal 10, json_data["meta"]["per_page"]
    assert_equal 25, json_data["meta"]["total_count"]
    assert_equal 3, json_data["meta"]["total_pages"]
  end

  test "API filtering and search" do
    create_text_note(@user, title: "Faith Journey", theme: "faith")
    create_text_note(@user, title: "Hope Springs", theme: "hope")
    create_text_note(@user, title: "Love Wins", theme: "love")

    @performance_tracker.track("API Search") do
      get "/api/text_notes?search=faith", headers: @headers
    end

    assert_response :success
    json_data = JSON.parse(response.body)
    
    assert_equal 1, json_data["text_notes"].count
    assert_includes json_data["text_notes"].first["title"], "Faith"
  end

  test "API theme filtering" do
    create_text_note(@user, theme: "faith")
    create_text_note(@user, theme: "hope")
    create_text_note(@user, theme: "faith")

    @performance_tracker.track("API Theme Filter") do
      get "/api/text_notes?theme=faith", headers: @headers
    end

    assert_response :success
    json_data = JSON.parse(response.body)
    
    assert_equal 2, json_data["text_notes"].count
    json_data["text_notes"].each do |note|
      assert_equal "faith", note["theme"]
    end
  end

  test "API authentication required" do
    session.clear

    @performance_tracker.track("API Auth Required") do
      get "/api/text_notes", headers: @headers
    end

    assert_response :unauthorized
    json_data = JSON.parse(response.body)
    
    assert_equal "Authentication required", json_data["error"]
  end

  test "API validation errors" do
    invalid_params = {
      title: "", # Invalid: blank
      content: "x" * 50001, # Invalid: too long
      note_type: "invalid" # Invalid: not allowed
    }

    @performance_tracker.track("API Validation Error") do
      post "/api/text_notes",
        params: { text_note: invalid_params }.to_json,
        headers: @headers
    end

    assert_response :unprocessable_entity
    json_data = JSON.parse(response.body)
    
    assert json_data.key?("errors")
    assert_includes json_data["errors"]["title"], "can't be blank"
    assert_includes json_data["errors"]["content"], "is too long"
  end

  test "API rate limiting" do
    # Make many requests to trigger rate limit
    30.times do |i|
      post "/api/text_notes",
        params: { text_note: { title: "Rate limit #{i}", content: "Test", note_type: "reflection" } }.to_json,
        headers: @headers
    end

    # Next request should be rate limited
    @performance_tracker.track("API Rate Limit") do
      post "/api/text_notes",
        params: { text_note: { title: "Rate limited", content: "Test", note_type: "reflection" } }.to_json,
        headers: @headers
    end

    assert_response :too_many_requests
    json_data = JSON.parse(response.body)
    assert_equal "Rate limit exceeded", json_data["error"]
  end

  test "API malicious input handling" do
    malicious_params = {
      title: "<script>alert('xss')</script>",
      content: "'; DROP TABLE text_notes; --",
      note_type: "reflection"
    }

    @performance_tracker.track("API Security") do
      post "/api/text_notes",
        params: { text_note: malicious_params }.to_json,
        headers: @headers
    end

    assert_response :unprocessable_entity
    json_data = JSON.parse(response.body)
    assert_includes json_data["errors"]["title"], "contains potentially malicious content"
  end

  test "API CORS headers" do
    @performance_tracker.track("API CORS Headers") do
      get "/api/text_notes", headers: @headers.merge("Origin" => "https://example.com")
    end

    assert_response :success
    assert_equal "*", response.headers["Access-Control-Allow-Origin"]
    assert_includes response.headers["Access-Control-Allow-Methods"], "GET"
  end

  test "API bulk operations" do
    text_notes = 3.times.map do |i|
      {
        title: "Bulk Note #{i}",
        content: "Bulk content #{i}",
        note_type: "reflection"
      }
    end

    assert_difference "TextNote.count", 3 do
      @performance_tracker.track("API Bulk Create") do
        post "/api/text_notes/bulk",
          params: { text_notes: text_notes }.to_json,
          headers: @headers
      end
    end

    assert_response :created
    json_data = JSON.parse(response.body)
    assert_equal 3, json_data["created_count"]
    assert_equal 3, json_data["text_notes"].count
  end

  test "API error response format" do
    # Trigger a not found error
    @performance_tracker.track("API Error Format") do
      get "/api/text_notes/99999", headers: @headers
    end

    assert_response :not_found
    json_data = JSON.parse(response.body)
    
    assert json_data.key?("error")
    assert json_data.key?("status")
    assert json_data.key?("timestamp")
    assert_equal 404, json_data["status"]
  end

  test "API performance metrics" do
    create_sample_text_notes(@user, 10)

    # Test that API responses are fast enough
    assert_performance_within(IntegrationTestHelper::PERFORMANCE_CONFIG[:api_response]) do
      get "/api/text_notes", headers: @headers
    end

    assert_performance_within(IntegrationTestHelper::PERFORMANCE_CONFIG[:api_response]) do
      post "/api/text_notes",
        params: { text_note: { title: "Performance Test", content: "Test", note_type: "reflection" } }.to_json,
        headers: @headers
    end
  end

  test "API concurrent requests" do
    assert_concurrent_performance(5, IntegrationTestHelper::PERFORMANCE_CONFIG[:api_concurrent_users]) do |user_index|
      post "/api/text_notes",
        params: { text_note: { title: "Concurrent #{user_index}", content: "Test", note_type: "reflection" } }.to_json,
        headers: @headers
    end

    assert_equal 5, TextNote.where("title LIKE ?", "Concurrent%").count
  end

  test "API memory usage" do
    assert_memory_within(IntegrationTestHelper::PERFORMANCE_CONFIG[:max_memory_per_operation]) do
      create_sample_text_notes(@user, 20)
      get "/api/text_notes", headers: @headers
    end
  end

  test "API analytics endpoint" do
    create_sample_text_notes(@user, 10)
    create_sample_sermons(@user, 5)

    @performance_tracker.track("API Analytics") do
      get "/api/analytics/dashboard", headers: @headers
    end

    assert_response :success
    json_data = JSON.parse(response.body)
    
    assert json_data.key?("text_notes_count")
    assert json_data.key?("sermons_count")
    assert json_data.key?("themes_breakdown")
    assert_equal 10, json_data["text_notes_count"]
    assert_equal 5, json_data["sermons_count"]
  end

  test "API export endpoint" do
    create_sample_text_notes(@user, 5)

    @performance_tracker.track("API Export") do
      get "/api/text_notes/export", headers: @headers.merge("Accept" => "application/json")
    end

    assert_response :success
    json_data = JSON.parse(response.body)
    
    assert json_data.key?("text_notes")
    assert json_data.key?("exported_at")
    assert json_data.key?("format_version")
    assert_equal 5, json_data["text_notes"].count
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

  def sign_in_user(user)
    session[:user_id] = user.id
    session[:signed_in_at] = Time.current
  end

  def create_text_note(user, attributes = {})
    default_attributes = {
      title: "API Test Note",
      content: "API test content",
      note_type: "reflection",
      theme: "faith",
      user: user
    }

    TextNote.create!(default_attributes.merge(attributes))
  end

  def create_sample_text_notes(user, count)
    count.times do |i|
      create_text_note(user, 
        title: "API Note #{i + 1}",
        content: "API content #{i + 1}",
        theme: %w[faith hope love grace mercy].sample
      )
    end
  end

  def create_sermon(user, attributes = {})
    default_attributes = {
      title: "API Test Sermon",
      source_url: "https://api-test.com/sermon",
      church: "API Test Church",
      pastor: "API Test Pastor",
      scripture: "API 1:1",
      interpretation: "API test interpretation",
      action_points: "API test actions",
      denomination: "API Test",
      sermon_date: 1.week.ago,
      audience_count: 100
    }

    Sermon.create!(default_attributes.merge(attributes))
  end

  def create_sample_sermons(user, count)
    count.times do |i|
      create_sermon(user,
        title: "API Sermon #{i + 1}",
        source_url: "https://api-test#{i}.com/sermon",
        church: "API Church #{i + 1}"
      )
    end
  end

  def create_video(sermon, attributes = {})
    default_attributes = {
      sermon: sermon,
      script: "API test video script",
      status: "pending",
      theme: "faith"
    }

    Video.create!(default_attributes.merge(attributes))
  end
end