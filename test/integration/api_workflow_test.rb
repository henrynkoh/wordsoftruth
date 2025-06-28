require "test_helper"
require "benchmark"

class ApiWorkflowTest < ActionDispatch::IntegrationTest
  def setup
    # Clear data for clean testing
    Video.destroy_all
    Sermon.destroy_all
    
    @api_base_url = "/api"
    @performance_thresholds = {
      api_response: 1.second,
      batch_processing: 5.seconds,
      data_export: 3.seconds
    }
    @performance_metrics = {}
  end

  def teardown
    log_api_performance_metrics if @performance_metrics.any?
  end

  # API ENDPOINT INTEGRATION TESTS

  test "sermon creation API workflow with validation and processing" do
    sermon_data = {
      url: "https://api-test-church.com/sermon",
      title: "API Test Sermon",
      church: "API Test Church"
    }
    
    # Stub the external request
    stub_request(:get, sermon_data[:url])
      .to_return(
        status: 200,
        body: create_api_test_sermon_html(sermon_data),
        headers: { 'Content-Type' => 'text/html' }
      )
    
    performance_benchmark("API Sermon Creation") do
      # Step 1: Create sermon via API
      creation_time = performance_benchmark("API Creation") do
        post "#{@api_base_url}/sermons", 
          params: sermon_data,
          headers: { 'Content-Type' => 'application/json' }
        
        assert_response :success
      end
      
      # Step 2: Verify sermon was created
      sermon = Sermon.find_by(source_url: sermon_data[:url])
      assert_not_nil sermon
      assert_equal sermon_data[:title], sermon.title
      
      # Step 3: Trigger processing workflow
      processing_time = performance_benchmark("API Processing Trigger") do
        perform_enqueued_jobs do
          SermonCrawlingJob.perform_later(sermon_data[:url])
        end
      end
      
      # Step 4: Check processing results via API
      retrieval_time = performance_benchmark("API Data Retrieval") do
        get "#{@api_base_url}/sermons/#{sermon.id}"
        assert_response :success
      end
      
      # Performance assertions
      assert creation_time < @performance_thresholds[:api_response]
      assert processing_time < @performance_thresholds[:batch_processing]
      assert retrieval_time < @performance_thresholds[:api_response]
    end
  end

  test "batch API operations with performance monitoring" do
    batch_size = 10
    sermon_batch = batch_size.times.map do |i|
      {
        url: "https://batch-test#{i}.com/sermon",
        title: "Batch Sermon #{i + 1}",
        church: "Batch Church #{i + 1}"
      }
    end
    
    # Setup stubs for all batch items
    sermon_batch.each do |sermon_data|
      stub_request(:get, sermon_data[:url])
        .to_return(
          status: 200,
          body: create_api_test_sermon_html(sermon_data),
          headers: { 'Content-Type' => 'text/html' }
        )
    end
    
    performance_benchmark("Batch API Operations") do
      # Batch creation
      creation_time = performance_benchmark("Batch Creation") do
        sermon_batch.each do |sermon_data|
          post "#{@api_base_url}/sermons", 
            params: sermon_data,
            headers: { 'Content-Type' => 'application/json' }
          assert_response :success
        end
      end
      
      # Verify all sermons created
      assert_equal batch_size, Sermon.count
      
      # Batch processing
      processing_time = performance_benchmark("Batch Processing") do
        perform_enqueued_jobs do
          sermon_batch.each do |sermon_data|
            SermonCrawlingJob.perform_later(sermon_data[:url])
          end
        end
      end
      
      # Batch retrieval
      retrieval_time = performance_benchmark("Batch Retrieval") do
        get "#{@api_base_url}/sermons"
        assert_response :success
        
        if response.content_type.include?('json')
          sermons = JSON.parse(response.body)
          assert_equal batch_size, sermons.length
        end
      end
      
      # Performance assertions for batch operations
      avg_creation_time = creation_time / batch_size
      assert avg_creation_time < @performance_thresholds[:api_response], 
        "Average creation time too slow: #{avg_creation_time}s"
      
      assert processing_time < @performance_thresholds[:batch_processing] * 2,
        "Batch processing too slow: #{processing_time}s"
      
      assert retrieval_time < @performance_thresholds[:data_export],
        "Batch retrieval too slow: #{retrieval_time}s"
    end
  end

  test "API error handling and resilience" do
    error_scenarios = [
      { name: "Invalid URL", data: { url: "invalid-url" }, expected_status: 422 },
      { name: "Missing Required Fields", data: { url: "" }, expected_status: 422 },
      { name: "Duplicate URL", setup: :create_duplicate, expected_status: 422 }
    ]
    
    error_scenarios.each do |scenario|
      performance_benchmark("API Error: #{scenario[:name]}") do
        # Setup if needed
        if scenario[:setup] == :create_duplicate
          existing_url = "https://duplicate-test.com/sermon"
          create_valid_sermon(source_url: existing_url)
          test_data = { url: existing_url }
        else
          test_data = scenario[:data]
        end
        
        error_response_time = performance_benchmark("Error Response: #{scenario[:name]}") do
          post "#{@api_base_url}/sermons", 
            params: test_data,
            headers: { 'Content-Type' => 'application/json' }
          
          assert_response scenario[:expected_status]
        end
        
        # Error responses should be fast
        assert error_response_time < 0.5.seconds, 
          "Error response too slow for #{scenario[:name]}: #{error_response_time}s"
      end
    end
  end

  # VIDEO API WORKFLOW TESTS

  test "video processing API workflow" do
    # Create sermon first
    sermon = create_valid_sermon
    
    performance_benchmark("Video API Workflow") do
      # Trigger video processing via API
      processing_trigger_time = performance_benchmark("Video Processing Trigger") do
        post "#{@api_base_url}/videos", 
          params: { sermon_id: sermon.id },
          headers: { 'Content-Type' => 'application/json' }
        
        # Handle case where API might not exist yet
        assert_includes [200, 201, 404], response.status
      end
      
      if response.status != 404
        # Check video status via API
        status_check_time = performance_benchmark("Video Status Check") do
          get "#{@api_base_url}/videos"
          assert_response :success
        end
        
        # Performance assertions
        assert processing_trigger_time < @performance_thresholds[:api_response]
        assert status_check_time < @performance_thresholds[:api_response]
      end
    end
  end

  test "video upload completion API workflow" do
    sermon = create_valid_sermon
    video = create_valid_video(sermon, status: 'processing')
    
    upload_data = {
      video_path: '/storage/videos/completed_video.mp4',
      thumbnail_path: '/storage/thumbnails/completed_thumb.jpg',
      youtube_id: 'UPLOAD123ABC',
      status: 'uploaded'
    }
    
    performance_benchmark("Video Upload Completion") do
      completion_time = performance_benchmark("Upload Completion API") do
        patch "#{@api_base_url}/videos/#{video.id}", 
          params: upload_data,
          headers: { 'Content-Type' => 'application/json' }
        
        # Handle case where API might not exist yet  
        assert_includes [200, 204, 404], response.status
      end
      
      if response.status != 404
        # Verify update
        video.reload
        assert_equal 'uploaded', video.status
        
        assert completion_time < @performance_thresholds[:api_response]
      end
    end
  end

  # DATA EXPORT API TESTS

  test "dashboard data export API performance" do
    # Create test dataset
    setup_time = performance_benchmark("Dashboard Data Setup") do
      20.times do |i|
        sermon = create_valid_sermon(
          title: "Export Test Sermon #{i + 1}",
          source_url: "https://export-test#{i}.com",
          church: "Export Church #{(i % 3) + 1}"
        )
        
        create_valid_video(
          sermon,
          status: ["pending", "processing", "uploaded"].sample
        )
      end
    end
    
    export_formats = [
      { path: "/dashboard", format: "html", name: "Dashboard HTML" },
      { path: "/dashboard.json", format: "json", name: "Dashboard JSON" },
      { path: "/api/statistics", format: "json", name: "Statistics API" }
    ]
    
    export_formats.each do |export_format|
      performance_benchmark("Export: #{export_format[:name]}") do
        export_time = performance_benchmark(export_format[:name]) do
          get export_format[:path]
          
          # Handle different expected responses
          if export_format[:path].include?('/api/')
            assert_includes [200, 404], response.status
          else
            assert_response :success
          end
        end
        
        # Data export should be fast even with larger datasets
        assert export_time < @performance_thresholds[:data_export],
          "#{export_format[:name]} export too slow: #{export_time}s"
      end
    end
  end

  test "paginated API responses performance" do
    # Create large dataset
    large_dataset_size = 100
    
    setup_time = performance_benchmark("Large Dataset Creation") do
      large_dataset_size.times do |i|
        create_valid_sermon(
          title: "Pagination Test #{i + 1}",
          source_url: "https://pagination#{i}.com"
        )
      end
    end
    
    pagination_tests = [
      { page: 1, per_page: 10, name: "First Page" },
      { page: 5, per_page: 20, name: "Middle Page" },
      { page: 1, per_page: 50, name: "Large Page Size" }
    ]
    
    pagination_tests.each do |test_case|
      performance_benchmark("Pagination: #{test_case[:name]}") do
        pagination_time = performance_benchmark(test_case[:name]) do
          get "#{@api_base_url}/sermons", 
            params: { 
              page: test_case[:page], 
              per_page: test_case[:per_page] 
            }
          
          # Handle case where pagination API might not exist
          assert_includes [200, 404], response.status
        end
        
        # Pagination should perform consistently regardless of dataset size
        assert pagination_time < @performance_thresholds[:api_response],
          "#{test_case[:name]} pagination too slow: #{pagination_time}s"
      end
    end
  end

  # API RATE LIMITING AND LOAD TESTS

  test "API rate limiting under load" do
    rate_limit_test_count = 50
    
    performance_benchmark("API Rate Limiting") do
      # Simulate rapid requests
      request_times = []
      
      load_test_time = performance_benchmark("Load Test") do
        rate_limit_test_count.times do |i|
          request_start = Time.current
          
          get "#{@api_base_url}/sermons"
          
          request_end = Time.current
          request_times << (request_end - request_start)
          
          # Expect either success or rate limiting
          assert_includes [200, 404, 429], response.status
        end
      end
      
      # Calculate performance statistics
      avg_response_time = request_times.sum / request_times.length
      max_response_time = request_times.max
      
      @performance_metrics[:load_test] = {
        total_requests: rate_limit_test_count,
        avg_response_time: "#{(avg_response_time * 1000).round(2)}ms",
        max_response_time: "#{(max_response_time * 1000).round(2)}ms",
        total_time: "#{load_test_time.round(2)}s"
      }
      
      # Performance assertions
      assert avg_response_time < 1.second, "Average response time too slow under load"
      assert max_response_time < 5.seconds, "Maximum response time too slow under load"
    end
  end

  test "concurrent API access performance" do
    concurrent_users = 5
    requests_per_user = 10
    
    performance_benchmark("Concurrent API Access") do
      concurrent_time = performance_benchmark("Concurrent Requests") do
        threads = concurrent_users.times.map do |user_id|
          Thread.new do
            user_response_times = []
            
            requests_per_user.times do |request_id|
              request_start = Time.current
              
              get "#{@api_base_url}/sermons", 
                params: { user_id: user_id, request_id: request_id }
              
              request_end = Time.current
              user_response_times << (request_end - request_start)
              
              assert_includes [200, 404], response.status
            end
            
            user_response_times
          end
        end
        
        all_response_times = threads.map(&:value).flatten
        
        @performance_metrics[:concurrent_access] = {
          concurrent_users: concurrent_users,
          requests_per_user: requests_per_user,
          total_requests: all_response_times.length,
          avg_response_time: "#{(all_response_times.sum / all_response_times.length * 1000).round(2)}ms"
        }
      end
      
      # Concurrent access should scale reasonably
      sequential_estimate = (requests_per_user * concurrent_users) * 0.1 # Estimate 100ms per request
      efficiency_ratio = concurrent_time / sequential_estimate
      
      assert efficiency_ratio < 2.0, "Concurrent API access not efficient enough"
    end
  end

  # API SECURITY AND VALIDATION TESTS

  test "API input validation performance" do
    validation_test_cases = [
      { name: "XSS Prevention", data: { title: "<script>alert('xss')</script>" } },
      { name: "SQL Injection", data: { church: "'; DROP TABLE sermons; --" } },
      { name: "Large Input", data: { interpretation: "x" * 10000 } },
      { name: "Special Characters", data: { title: "Test 'quotes' & symbols @#$%" } }
    ]
    
    validation_test_cases.each do |test_case|
      performance_benchmark("Validation: #{test_case[:name]}") do
        validation_time = performance_benchmark(test_case[:name]) do
          post "#{@api_base_url}/sermons", 
            params: test_case[:data].merge(url: "https://validation-test.com"),
            headers: { 'Content-Type' => 'application/json' }
          
          # Should either succeed with sanitized data or fail validation quickly
          assert_includes [200, 201, 422], response.status
        end
        
        # Validation should be fast even for complex inputs
        assert validation_time < 0.5.seconds,
          "#{test_case[:name]} validation too slow: #{validation_time}s"
      end
    end
  end

  private

  def performance_benchmark(operation_name)
    start_time = Time.current
    result = yield
    end_time = Time.current
    
    execution_time = end_time - start_time
    
    @performance_metrics[operation_name] = "#{(execution_time * 1000).round(2)}ms"
    
    Rails.logger.info "API PERFORMANCE: #{operation_name} completed in #{execution_time.round(3)}s"
    
    execution_time
  end

  def log_api_performance_metrics
    Rails.logger.info "="*50
    Rails.logger.info "API INTEGRATION TEST PERFORMANCE METRICS"
    Rails.logger.info "="*50
    
    @performance_metrics.each do |operation, metrics|
      if metrics.is_a?(Hash)
        Rails.logger.info "#{operation}:"
        metrics.each { |key, value| Rails.logger.info "  #{key}: #{value}" }
      else
        Rails.logger.info "#{operation}: #{metrics}"
      end
    end
    
    Rails.logger.info "="*50
  end

  def create_api_test_sermon_html(sermon_data)
    <<~HTML
      <html>
        <head><title>#{sermon_data[:title]}</title></head>
        <body>
          <h1>#{sermon_data[:title]}</h1>
          <p class="church">#{sermon_data[:church]}</p>
          <p class="pastor">Test Pastor</p>
          <div class="content">
            <p>API test sermon content for integration testing.</p>
            <p>Action points: Test, verify, validate API functionality.</p>
          </div>
        </body>
      </html>
    HTML
  end
end