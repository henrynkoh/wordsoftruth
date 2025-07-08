# frozen_string_literal: true

require "test_helper"

class SermonAutomationTest < ActionDispatch::IntegrationTest
  def setup
    super
    @user = create_authenticated_user
    @sermon_url = "https://example-church.com/sermons/faith-in-action"
    @sermon_data = {
      title: "Faith in Action: Living Out Our Beliefs",
      church: "Grace Community Church",
      pastor: "Pastor John Smith",
      scripture: "James 2:14-26",
      interpretation: "James challenges us to understand that faith without works is dead. This doesn't mean we are saved by works, but that genuine faith naturally produces good works. When we truly believe in Christ, our lives will reflect that belief through our actions. This passage teaches us that faith and works are inseparable - not as a means of earning salvation, but as evidence of genuine faith.",
      action_points: "1. Examine your faith - does it produce good works? 2. Look for opportunities to serve others this week. 3. Practice generosity with your time and resources. 4. Share your faith through both words and actions.",
      denomination: "Baptist",
      sermon_date: 1.week.ago,
      audience_count: 150
    }
  end

  test "successful sermon automation workflow" do
    stub_successful_sermon_crawling(@sermon_url, @sermon_data)
    stub_video_generation_success

    @performance_tracker.track("Complete Sermon Workflow") do
      post sermon_automation_index_path, params: { 
        sermon: { source_url: @sermon_url }
      }
    end

    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert_includes response.body, "Sermon processing started"

    # Verify sermon was created
    sermon = Sermon.last
    assert_equal @sermon_data[:title], sermon.title
    assert_equal @sermon_data[:church], sermon.church
    assert_equal @sermon_data[:pastor], sermon.pastor
    assert_equal @sermon_url, sermon.source_url

    # Verify video job was enqueued
    assert_enqueued_with(job: OptimizedVideoProcessingJob, args: [sermon.id])
  end

  test "sermon crawling with invalid URL" do
    invalid_urls = [
      "not-a-url",
      "javascript:alert('xss')",
      "ftp://malicious.com/file",
      "http://localhost/internal",
      "https://192.168.1.1/private"
    ]

    invalid_urls.each do |invalid_url|
      @performance_tracker.track("Invalid URL Handling") do
        post sermon_automation_index_path, params: { 
          sermon: { source_url: invalid_url }
        }
      end

      assert_response :unprocessable_entity
      assert_includes response.body, "Invalid URL"
    end
  end

  test "sermon crawling with failed HTTP request" do
    stub_failed_sermon_crawling(@sermon_url, 404)

    @performance_tracker.track("Failed HTTP Request") do
      post sermon_automation_index_path, params: { 
        sermon: { source_url: @sermon_url }
      }
    end

    assert_response :redirect
    follow_redirect!
    assert_includes response.body, "Failed to fetch sermon content"
  end

  test "sermon crawling with timeout" do
    stub_slow_sermon_crawling(@sermon_url, 10.seconds)

    @performance_tracker.track("HTTP Timeout Handling") do
      post sermon_automation_index_path, params: { 
        sermon: { source_url: @sermon_url }
      }
    end

    assert_response :redirect
    follow_redirect!
    assert_includes response.body, "Request timed out"
  end

  test "duplicate sermon prevention" do
    stub_successful_sermon_crawling(@sermon_url, @sermon_data)
    
    # Create initial sermon
    post sermon_automation_index_path, params: { 
      sermon: { source_url: @sermon_url }
    }

    # Try to create duplicate
    assert_no_difference "Sermon.count" do
      @performance_tracker.track("Duplicate Prevention") do
        post sermon_automation_index_path, params: { 
          sermon: { source_url: @sermon_url }
        }
      end
    end

    assert_response :redirect
    follow_redirect!
    assert_includes response.body, "Sermon already exists"
  end

  test "sermon content validation and sanitization" do
    malicious_data = @sermon_data.merge(
      title: "<script>alert('xss')</script>Malicious Title",
      interpretation: "'; DROP TABLE sermons; -- This is malicious",
      action_points: "<iframe src='javascript:alert(1)'></iframe>Bad content"
    )

    stub_successful_sermon_crawling(@sermon_url, malicious_data)

    @performance_tracker.track("Content Sanitization") do
      post sermon_automation_index_path, params: { 
        sermon: { source_url: @sermon_url }
      }
    end

    assert_response :redirect
    follow_redirect!

    sermon = Sermon.last
    assert_sanitized_content(sermon.title)
    assert_sanitized_content(sermon.interpretation)
    assert_sanitized_content(sermon.action_points)
    assert_not_includes sermon.title, "<script>"
    assert_not_includes sermon.interpretation, "DROP TABLE"
    assert_not_includes sermon.action_points, "<iframe>"
  end

  test "batch sermon processing" do
    urls = [
      "https://church1.com/sermon1",
      "https://church2.com/sermon2", 
      "https://church3.com/sermon3"
    ]

    urls.each_with_index do |url, index|
      data = @sermon_data.merge(title: "Sermon #{index + 1}")
      stub_successful_sermon_crawling(url, data)
    end

    assert_difference "Sermon.count", 3 do
      @performance_tracker.track("Batch Processing") do
        post batch_sermon_automation_path, params: { 
          sermon_urls: urls.join("\n")
        }
      end
    end

    assert_response :redirect
    follow_redirect!
    assert_includes response.body, "3 sermons processed successfully"
  end

  test "sermon processing with Korean content" do
    korean_data = @sermon_data.merge(
      title: "믿음으로 사는 삶",
      interpretation: "우리는 믿음으로 살아야 합니다. 하나님의 사랑은 영원하며, 그의 은혜는 충분합니다.",
      action_points: "1. 매일 기도하십시오. 2. 성경을 읽으십시오. 3. 다른 사람들을 사랑하십시오."
    )

    stub_successful_sermon_crawling(@sermon_url, korean_data)

    @performance_tracker.track("Korean Content Processing") do
      post sermon_automation_index_path, params: { 
        sermon: { source_url: @sermon_url }
      }
    end

    assert_response :redirect
    sermon = Sermon.last
    assert_equal korean_data[:title], sermon.title
    assert_equal korean_data[:interpretation], sermon.interpretation
    assert_equal korean_data[:action_points], sermon.action_points
  end

  test "sermon processing progress tracking" do
    stub_successful_sermon_crawling(@sermon_url, @sermon_data)

    post sermon_automation_index_path, params: { 
      sermon: { source_url: @sermon_url }
    }

    sermon = Sermon.last

    @performance_tracker.track("Progress Tracking") do
      xhr_get sermon_progress_path(sermon)
    end

    assert_response :success
    assert_equal "application/json", response.content_type
    
    progress_data = JSON.parse(response.body)
    assert progress_data.key?("status")
    assert progress_data.key?("progress_percentage")
    assert progress_data.key?("current_step")
  end

  test "sermon automation dashboard" do
    create_sample_sermons_for_user(@user, 10)

    @performance_tracker.track("Dashboard Load") do
      get sermon_automation_index_path
    end

    assert_response :success
    assert_includes response.body, "Sermon Automation"
    assert_includes response.body, "10 sermons"
    assert_includes response.body, "Add New Sermon"
  end

  test "sermon filtering and search" do
    create_sermon_for_user(@user, title: "Faith and Hope", church: "Grace Church")
    create_sermon_for_user(@user, title: "Love Conquers All", church: "Hope Chapel")
    create_sermon_for_user(@user, title: "Trust in God", church: "Faith Community")

    @performance_tracker.track("Sermon Search") do
      get sermon_automation_index_path, params: { search: "faith" }
    end

    assert_response :success
    assert_includes response.body, "Faith and Hope"
    assert_includes response.body, "Trust in God"
    assert_not_includes response.body, "Love Conquers All"
  end

  test "sermon export functionality" do
    create_sample_sermons_for_user(@user, 5)

    @performance_tracker.track("Sermon Export") do
      get export_sermons_path, params: { format: "csv" }
    end

    assert_response :success
    assert_equal "text/csv", response.content_type
    assert_includes response.headers["Content-Disposition"], "sermons_export"
  end

  test "sermon statistics and analytics" do
    create_sample_sermons_for_user(@user, 20)

    @performance_tracker.track("Statistics Generation") do
      get sermon_statistics_path
    end

    assert_response :success
    assert_includes response.body, "Total Sermons: 20"
    assert_includes response.body, "Churches"
    assert_includes response.body, "Denominations"
    assert_includes response.body, "Average Audience"
  end

  test "concurrent sermon processing" do
    urls = 5.times.map { |i| "https://test#{i}.com/sermon" }
    
    urls.each_with_index do |url, index|
      data = @sermon_data.merge(title: "Concurrent Sermon #{index}")
      stub_successful_sermon_crawling(url, data)
    end

    assert_concurrent_performance(5, 10.seconds) do |index|
      post sermon_automation_index_path, params: { 
        sermon: { source_url: urls[index] }
      }
    end

    assert_equal 5, Sermon.where("title LIKE ?", "Concurrent Sermon%").count
  end

  test "sermon automation performance meets requirements" do
    stub_successful_sermon_crawling(@sermon_url, @sermon_data)

    assert_performance_within(IntegrationTestHelper::PERFORMANCE_CONFIG[:sermon_ingestion]) do
      post sermon_automation_index_path, params: { 
        sermon: { source_url: @sermon_url }
      }
    end
  end

  test "sermon automation memory usage is reasonable" do
    stub_successful_sermon_crawling(@sermon_url, @sermon_data)

    assert_memory_within(IntegrationTestHelper::PERFORMANCE_CONFIG[:max_memory_per_operation]) do
      post sermon_automation_index_path, params: { 
        sermon: { source_url: @sermon_url }
      }
    end
  end

  test "sermon automation rate limiting" do
    # Test rate limiting for sermon submissions
    20.times do |i|
      url = "https://spam#{i}.com/sermon"
      stub_successful_sermon_crawling(url, @sermon_data)
      post sermon_automation_index_path, params: { 
        sermon: { source_url: url }
      }
    end

    # Next request should be rate limited
    post sermon_automation_index_path, params: { 
      sermon: { source_url: "https://blocked.com/sermon" }
    }

    assert_response :too_many_requests
    assert_includes response.body, "Rate limit exceeded"
  end

  test "sermon processing error recovery" do
    # Test that system recovers gracefully from errors
    stub_failed_sermon_crawling(@sermon_url, 500)

    post sermon_automation_index_path, params: { 
      sermon: { source_url: @sermon_url }
    }

    assert_response :redirect
    follow_redirect!
    assert_includes response.body, "An error occurred"

    # Verify system is still responsive
    get sermon_automation_index_path
    assert_response :success
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

  def create_sermon_for_user(user, attributes = {})
    default_attributes = {
      title: "Test Sermon",
      source_url: "https://test.com/sermon",
      church: "Test Church",
      pastor: "Test Pastor",
      scripture: "Test 1:1",
      interpretation: "Test interpretation content",
      action_points: "Test action points",
      denomination: "Test",
      sermon_date: 1.week.ago,
      audience_count: 100
    }

    Sermon.create!(default_attributes.merge(attributes))
  end

  def create_sample_sermons_for_user(user, count)
    count.times do |i|
      create_sermon_for_user(user,
        title: "Test Sermon #{i + 1}",
        source_url: "https://test#{i}.com/sermon",
        church: "Church #{i + 1}",
        pastor: "Pastor #{i + 1}"
      )
    end
  end

  def sermon_automation_index_path
    "/"
  end

  def batch_sermon_automation_path
    "/sermon_automation/batch"
  end

  def sermon_progress_path(sermon)
    "/sermon_automation/#{sermon.id}/progress"
  end

  def export_sermons_path
    "/sermon_automation/export"
  end

  def sermon_statistics_path
    "/sermon_automation/statistics"
  end
end