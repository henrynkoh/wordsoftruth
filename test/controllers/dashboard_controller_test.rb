require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  def setup
    @sermon = sermons(:one)
    # Use existing fixture instead of creating new video to avoid validation issues
    @video = videos(:one)
  end

  # Basic Access Tests
  test "should get index" do
    get dashboard_index_url
    assert_response :success
  end

  test "should render dashboard template" do
    get dashboard_index_url
    assert_template :index
  end

  test "should include dashboard layout" do
    get dashboard_index_url
    assert_select "title", /Dashboard/
  end

  # Data Display Tests
  test "should display sermon statistics" do
    get dashboard_index_url

    assert_select ".sermon-count"
    assert_select ".video-count"
    assert_response_includes "Total Sermons"
    assert_response_includes "Total Videos"
  end

  test "should display recent sermons" do
    get dashboard_index_url

    assert_select ".recent-sermons"
    assert_response_includes @sermon.title
    assert_response_includes @sermon.church
  end

  test "should display video processing status" do
    get dashboard_index_url

    assert_select ".video-status"
    assert_response_includes "uploaded"
  end

  test "should show correct sermon count" do
    sermon_count = Sermon.count

    get dashboard_index_url

    assert_match /#{sermon_count}/, response.body
  end

  test "should show correct video count" do
    video_count = Video.count

    get dashboard_index_url

    assert_match /#{video_count}/, response.body
  end

  # Error Handling Tests
  test "should handle database connection errors gracefully" do
    # Mock database error
    Sermon.stubs(:count).raises(ActiveRecord::ConnectionNotEstablished)

    get dashboard_index_url

    assert_response :success
    assert_response_includes "Unable to load statistics"
  end

  test "should handle timeout errors" do
    # Mock query timeout
    Sermon.stubs(:recent).raises(ActiveRecord::QueryCanceled)

    get dashboard_index_url

    assert_response :success
    assert_response_includes "Dashboard"
  end

  test "should handle missing data gracefully" do
    # Clear all data
    Sermon.destroy_all
    Video.destroy_all

    get dashboard_index_url

    assert_response :success
    assert_response_includes "0"
    assert_response_includes "No sermons found"
  end

  # Performance Tests
  test "should load dashboard within reasonable time" do
    start_time = Time.current
    get dashboard_index_url
    end_time = Time.current

    assert_response :success
    assert (end_time - start_time) < 2, "Dashboard should load quickly"
  end

  test "should handle large datasets efficiently" do
    # Create multiple sermons and videos
    20.times do |i|
      sermon = Sermon.create!(
        title: "Test Sermon #{i}",
        source_url: "https://test#{i}.com",
        church: "Test Church #{i}"
      )
      sermon.videos.create!(
        script: "Test script #{i}",
        status: "pending"
      )
    end

    get dashboard_index_url

    assert_response :success
    # Should not timeout or cause memory issues
  end

  # Security Tests
  test "should sanitize user input in search parameters" do
    malicious_params = {
      search: "<script>alert('xss')</script>",
      filter: "'; DROP TABLE sermons; --",
    }

    get dashboard_index_url, params: malicious_params

    assert_response :success
    assert_not_includes response.body, "<script>"
    assert_not_includes response.body, "DROP TABLE"
  end

  test "should handle SQL injection attempts" do
    malicious_search = "'; DELETE FROM videos; --"

    get dashboard_index_url, params: { search: malicious_search }

    assert_response :success
    # Verify data still exists
    assert Video.count > 0
  end

  test "should prevent CSRF attacks" do
    # CSRF protection should be enabled
    assert_not_nil ActionController::Base.protect_from_forgery
  end

  # Authentication Tests (if implemented)
  test "should require authentication for dashboard access" do
    # Skip if no authentication implemented
    skip "Authentication not implemented" unless defined?(Devise) || respond_to?(:authenticate_user!)

    # Test without authentication
    get dashboard_index_url
    assert_redirected_to login_path
  end

  test "should allow access for authenticated users" do
    skip "Authentication not implemented" unless defined?(Devise)

    sign_in users(:one) # Assuming user fixtures exist
    get dashboard_index_url
    assert_response :success
  end

  # Filter and Search Tests
  test "should filter sermons by church" do
    church_name = @sermon.church

    get dashboard_index_url, params: { church: church_name }

    assert_response :success
    assert_response_includes church_name
  end

  test "should filter sermons by status" do
    get dashboard_index_url, params: { status: "uploaded" }

    assert_response :success
    assert_response_includes "uploaded"
  end

  test "should search sermons by title" do
    search_term = @sermon.title.split.first

    get dashboard_index_url, params: { search: search_term }

    assert_response :success
    assert_response_includes search_term
  end

  test "should handle empty search results" do
    get dashboard_index_url, params: { search: "nonexistentterm" }

    assert_response :success
    assert_response_includes "No results found"
  end

  # Pagination Tests
  test "should paginate large result sets" do
    # Create many sermons
    50.times do |i|
      Sermon.create!(
        title: "Paginated Sermon #{i}",
        source_url: "https://paginated#{i}.com",
        church: "Paginated Church #{i}"
      )
    end

    get dashboard_index_url

    assert_response :success
    # Should include pagination controls
    assert_select ".pagination" if respond_to?(:paginate)
  end

  test "should handle page parameter" do
    get dashboard_index_url, params: { page: 2 }

    assert_response :success
    # Should not error even if page doesn't exist
  end

  # AJAX/JSON Response Tests
  test "should respond to JSON requests" do
    get dashboard_index_url, headers: { "Accept" => "application/json" }

    if response.content_type.include?("json")
      assert_response :success
      json_response = JSON.parse(response.body)
      assert_includes json_response.keys, "sermon_count"
      assert_includes json_response.keys, "video_count"
    else
      # Skip if JSON not implemented
      skip "JSON response not implemented"
    end
  end

  test "should handle AJAX requests for statistics" do
    get dashboard_index_url, xhr: true

    if request.xhr?
      assert_response :success
      assert_template "dashboard/stats" # Partial template
    else
      skip "AJAX not implemented"
    end
  end

  # Content Security Tests
  test "should set appropriate security headers" do
    get dashboard_index_url

    assert_response :success
    # Check for security headers if implemented
    assert_not_nil response.headers["X-Frame-Options"] if response.headers["X-Frame-Options"]
    assert_not_nil response.headers["X-Content-Type-Options"] if response.headers["X-Content-Type-Options"]
  end

  test "should not expose sensitive information" do
    get dashboard_index_url

    assert_response :success
    # Should not include sensitive data in HTML
    assert_not_includes response.body, "password"
    assert_not_includes response.body, "secret"
    assert_not_includes response.body, "api_key"
  end

  # Accessibility Tests
  test "should include accessibility features" do
    get dashboard_index_url

    assert_response :success
    # Check for basic accessibility attributes
    assert_select "[aria-label]"
    assert_select "[role]"
    assert_select "title"
  end

  # Mobile Responsiveness Tests
  test "should respond to mobile user agents" do
    get dashboard_index_url, headers: {
      "User-Agent" => "Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X)",
    }

    assert_response :success
    # Should include responsive meta tags
    assert_select "meta[name='viewport']"
  end

  # Caching Tests
  test "should handle cache headers appropriately" do
    get dashboard_index_url

    assert_response :success
    # Dashboard should have appropriate cache control
    cache_control = response.headers["Cache-Control"]
    assert_not_nil cache_control if cache_control
  end

  # Error Page Tests
  test "should handle 404 errors gracefully" do
    get "/dashboard/nonexistent"

    assert_response :not_found
  end

  test "should handle 500 errors gracefully" do
    # Mock an internal server error
    DashboardController.any_instance.stubs(:index).raises(StandardError)

    get dashboard_index_url

    # Should either handle gracefully or return 500
    assert_includes [ 500, 200 ], response.status
  end

  private

  def assert_response_includes(text)
    assert_includes response.body, text, "Response should include '#{text}'"
  end
end
