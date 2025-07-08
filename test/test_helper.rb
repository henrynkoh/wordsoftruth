ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"
require "mocha/minitest"

# Code coverage configuration (disabled for test debugging)
# require "simplecov"
# SimpleCov.start "rails" do
#   add_filter "/bin/"
#   add_filter "/db/"
#   add_filter "/spec/" # if using both RSpec and Minitest
#   add_filter "/test/"
#   add_filter "/vendor/"
#   add_filter "/config/"
#   add_filter "/coverage/"
#
#   add_group "Models", "app/models"
#   add_group "Controllers", "app/controllers"
#   add_group "Services", "app/services"
#   add_group "Jobs", "app/jobs"
#   add_group "Helpers", "app/helpers"
#   add_group "Mailers", "app/mailers"
#   add_group "Libraries", "lib"
#
#   # Coverage thresholds
#   minimum_coverage 80
#   minimum_coverage_by_file 70
#
#   # Refuse to run if coverage drops below threshold
#   refuse_coverage_drop
# end

# WebMock configuration for testing HTTP requests
WebMock.disable_net_connect!(allow_localhost: true)

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

    # Test helper for creating valid sermon
    def create_valid_sermon(attributes = {})
      default_attributes = {
        title: "Faith and Hope in Difficult Times #{SecureRandom.hex(4)}",
        source_url: "https://gracecommunity-test-#{SecureRandom.hex(4)}.org/sermons/faith-hope",
        church: "Grace Community Test Church #{SecureRandom.hex(2)}",
        pastor: "Pastor John Smith",
        scripture: "Romans 8:28",
        interpretation: "Paul reminds us that even in our darkest moments, God is working behind the scenes orchestrating events for our good. This doesn't mean everything that happens is inherently good, but that our sovereign God can bring good from any situation when we love Him and are called according to His purpose. Our faith allows us to trust in His perfect plan even when we cannot see the outcome or understand the circumstances. This truth provides comfort during trials, strength during weakness, and hope during despair. When we embrace this biblical principle, we can face difficulties with confidence knowing that God's love never fails and His plans never change.",
        action_points: "1. Trust in God's timing and plan for your life. 2. Pray daily for wisdom and strength during difficult times. 3. Serve others who are going through similar challenges. 4. Study Scripture regularly to understand God's character and promises. 5. Practice gratitude even in difficult circumstances.",
        denomination: "Baptist",
        sermon_date: 1.week.ago,
        audience_count: 100,
      }

      Sermon.create!(default_attributes.merge(attributes))
    end

    # Test helper for creating valid video
    def create_valid_video(sermon = nil, attributes = {})
      sermon ||= create_valid_sermon

      default_attributes = {
        sermon: sermon,
        script: "Welcome to Grace Community Church. Today we explore the powerful message of Romans 8:28 about Faith and Hope in Difficult Times. Paul reminds us that God works ALL things together for good for those who love Him and are called according to His purpose. Even in our darkest moments, God is working behind the scenes orchestrating events for our benefit. This truth provides comfort during trials and strength during weakness. Trust in His timing, pray for wisdom, and serve others who are struggling.",
        status: "pending",
      }

      Video.create!(default_attributes.merge(attributes))
    end

    # Helper for stubbing external HTTP requests
    def stub_http_request(url, response_body, status: 200, headers: {})
      default_headers = { "Content-Type" => "text/html" }
      WebMock.stub_request(:get, url)
        .to_return(
          status: status,
          body: response_body,
          headers: default_headers.merge(headers)
        )
    end

    # Helper for creating test files
    def create_test_file(path, content = "test content")
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, content)
    end

    # Helper for cleaning up test files
    def cleanup_test_files(*paths)
      paths.each do |path|
        File.delete(path) if File.exist?(path)
        dir = File.dirname(path)
        Dir.rmdir(dir) if Dir.exist?(dir) && Dir.empty?(dir)
      end
    end

    # Helper for asserting file existence
    def assert_file_exists(path, message = nil)
      message ||= "Expected file to exist at #{path}"
      assert File.exist?(path), message
    end

    # Helper for asserting file content
    def assert_file_content(path, expected_content, message = nil)
      assert_file_exists(path)
      actual_content = File.read(path)
      message ||= "File content does not match expected content"
      assert_includes actual_content, expected_content, message
    end

    # Helper for testing job enqueuing
    def assert_job_enqueued(job_class, *args)
      assert_enqueued_with(job: job_class, args: args) do
        yield
      end
    end

    # Helper for testing job execution
    def perform_job(job_class, *args)
      perform_enqueued_jobs do
        job_class.perform_later(*args)
      end
    end

    # Security testing helpers
    def malicious_inputs
      [
        "<script>alert('xss')</script>",
        "javascript:alert('xss')",
        "'; DROP TABLE sermons; --",
        "../../../etc/passwd",
        "<iframe src='javascript:alert(1)'></iframe>",
        "<img onerror='alert(1)' src='x'>",
        "data:text/html,<script>alert('xss')</script>",
      ]
    end

    def private_ip_urls
      [
        "http://127.0.0.1/test",
        "http://localhost/test",
        "http://10.0.0.1/test",
        "http://172.16.0.1/test",
        "http://192.168.1.1/test",
        "http://169.254.169.254/test",
      ]
    end

    # Performance testing helper
    def assert_performance(max_time_seconds = 1)
      start_time = Time.current
      yield
      end_time = Time.current
      actual_time = end_time - start_time

      assert actual_time <= max_time_seconds,
        "Expected operation to complete within #{max_time_seconds}s but took #{actual_time}s"
    end

    # Assertion helper for response content
    def assert_response_includes(content, message = nil)
      message ||= "Expected response to include '#{content}'"
      assert_includes response.body, content, message
    end

    def assert_response_excludes(content, message = nil)
      message ||= "Expected response to not include '#{content}'"
      assert_not_includes response.body, content, message
    end

    # Database testing helpers
    def assert_record_count(model_class, expected_count, message = nil)
      actual_count = model_class.count
      message ||= "Expected #{model_class.name} count to be #{expected_count} but was #{actual_count}"
      assert_equal expected_count, actual_count, message
    end

    def assert_record_created(model_class, attributes = {})
      assert_difference "#{model_class.name}.count", 1 do
        yield
      end

      if attributes.any?
        record = model_class.last
        attributes.each do |key, value|
          assert_equal value, record.send(key), "Expected #{key} to be #{value}"
        end
      end
    end

    def assert_record_not_created(model_class)
      assert_no_difference "#{model_class.name}.count" do
        yield
      end
    end

    # Log testing helper
    def assert_logged(pattern, level: :info)
      Rails.logger.expects(level).with(regexp_matches(pattern))
      yield
    end

    # Mock external services for testing
    def mock_sermon_crawler_service(success: true, sermon: nil, error: nil)
      result = mock("crawler_result")
      result.stubs(:success?).returns(success)

      if success
        result.stubs(:sermon).returns(sermon || create_valid_sermon)
        result.stubs(:error).returns(nil)
      else
        result.stubs(:sermon).returns(nil)
        result.stubs(:error).returns(error || "Mock error")
      end

      service = mock("crawler_service")
      service.stubs(:crawl).returns(result)
      SermonCrawlerService.stubs(:new).returns(service)

      result
    end

    def mock_video_generator_service(success: true, video_path: nil, error: nil)
      result = mock("generator_result")
      result.stubs(:success?).returns(success)

      if success
        result.stubs(:video_path).returns(video_path || "/tmp/test_video.mp4")
        result.stubs(:thumbnail_path).returns("/tmp/test_thumbnail.jpg")
        result.stubs(:error).returns(nil)
      else
        result.stubs(:video_path).returns(nil)
        result.stubs(:thumbnail_path).returns(nil)
        result.stubs(:error).returns(error || "Mock error")
      end

      service = mock("generator_service")
      service.stubs(:generate_video).returns(result)
      VideoGeneratorService.stubs(:new).returns(service)

      result
    end

    # Test data cleanup
    def cleanup_test_data
      Video.destroy_all
      Sermon.destroy_all
      # Add other models as needed
    end

    # Freeze time for consistent testing
    def with_frozen_time(time = Time.current)
      travel_to(time) do
        yield
      end
    end
  end
end

# Configure ActiveJob for testing
class ActiveJob::TestCase
  include ActiveJob::TestHelper

  def setup
    clear_enqueued_jobs
    clear_performed_jobs
  end

  def teardown
    clear_enqueued_jobs
    clear_performed_jobs
  end
end

# Integration test helpers
class ActionDispatch::IntegrationTest
  # Helper for testing JSON responses
  def json_response
    @json_response ||= JSON.parse(response.body)
  end

  # Helper for authentication (when implemented)
  def sign_in_as(user)
    # Implementation depends on authentication system
    # post login_path, params: { email: user.email, password: 'password' }
    # or use Devise test helpers if available
  end

  # Helper for testing AJAX requests
  def xhr_get(path, params: {}, headers: {})
    get path, params: params, headers: headers.merge("X-Requested-With" => "XMLHttpRequest")
  end

  def xhr_post(path, params: {}, headers: {})
    post path, params: params, headers: headers.merge("X-Requested-With" => "XMLHttpRequest")
  end
end

# System test configuration (if using system tests)
if defined?(ApplicationSystemTestCase)
  class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
    driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

    def setup
      # System test setup
    end

    def teardown
      # System test cleanup
    end
  end
end

# Custom assertions for sermon-specific testing
module SermonTestAssertions
  def assert_valid_sermon_url(url)
    assert_match URI::DEFAULT_PARSER.make_regexp, url, "Invalid URL format: #{url}"
    refute_match /^(javascript|data|file):/, url, "Unsafe URL scheme: #{url}"
  end

  def assert_sanitized_content(content)
    refute_match /<script/i, content, "Content contains unsafe script tags"
    refute_match /<iframe/i, content, "Content contains unsafe iframe tags"
    refute_match /javascript:/i, content, "Content contains javascript: protocol"
    refute_match /on\w+\s*=/i, content, "Content contains inline event handlers"
  end

  def assert_valid_video_script(script)
    assert script.length >= 10, "Video script too short (minimum 10 characters)"
    assert script.length <= 10_000, "Video script too long (maximum 10,000 characters)"
    assert_sanitized_content(script)
  end
end

# Include custom assertions in all test classes
ActiveSupport::TestCase.include SermonTestAssertions
ActionDispatch::IntegrationTest.include SermonTestAssertions
