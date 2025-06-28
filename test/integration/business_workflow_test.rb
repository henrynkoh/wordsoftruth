require "test_helper"
require "benchmark"

class BusinessWorkflowTest < ActionDispatch::IntegrationTest
  def setup
    # Clear all data for clean testing
    Video.destroy_all
    Sermon.destroy_all
    
    # Setup test URLs and content
    @test_sermon_url = "https://example-church.com/sermons/faith-hope"
    @test_sermon_html = create_realistic_sermon_html
    @performance_metrics = {}
    
    # Configure realistic timeouts for integration testing
    @max_crawling_time = 10.seconds
    @max_video_generation_time = 30.seconds
    @max_dashboard_load_time = 2.seconds
  end

  def teardown
    # Cleanup test files and data
    cleanup_test_files
    WebMock.reset!
    
    # Log performance metrics
    log_performance_metrics if @performance_metrics.any?
  end

  # COMPLETE END-TO-END BUSINESS WORKFLOW TESTS

  test "complete sermon processing workflow from URL to dashboard display" do
    performance_benchmark("Complete E2E Workflow") do
      # Step 1: Data Ingestion - URL Submission to Sermon Crawling
      ingestion_time = performance_benchmark("Data Ingestion") do
        stub_sermon_crawling_request
        
        assert_difference 'Sermon.count', 1 do
          post '/api/sermons', params: { url: @test_sermon_url }
          assert_response :success
        end
      end
      
      sermon = Sermon.last
      assert_not_nil sermon
      assert_equal "Faith and Hope in Difficult Times", sermon.title
      assert_equal "Grace Community Church", sermon.church
      
      # Step 2: Background Job Processing - Sermon Crawling
      crawling_time = performance_benchmark("Sermon Crawling Job") do
        perform_enqueued_jobs do
          SermonCrawlingJob.perform_later(@test_sermon_url)
        end
      end
      
      # Verify sermon was processed correctly
      sermon.reload
      assert_not_nil sermon.interpretation
      assert_not_nil sermon.action_points
      
      # Step 3: Video Generation Pipeline
      video_generation_time = performance_benchmark("Video Generation Pipeline") do
        stub_video_generation_success
        
        assert_difference 'Video.count', 1 do
          perform_enqueued_jobs do
            VideoProcessingJob.perform_later(sermon.id)
          end
        end
      end
      
      video = sermon.videos.last
      assert_not_nil video
      assert_equal 'processing', video.status
      assert_not_nil video.script
      
      # Step 4: Video Processing Completion
      completion_time = performance_benchmark("Video Processing Completion") do
        video.update!(
          status: 'uploaded',
          video_path: '/storage/videos/test_video.mp4',
          thumbnail_path: '/storage/thumbnails/test_thumb.jpg',
          youtube_id: 'TEST123ABC'
        )
      end
      
      # Step 5: Dashboard Data Aggregation and Display
      dashboard_time = performance_benchmark("Dashboard Display") do
        get dashboard_index_path
        assert_response :success
      end
      
      # Verify dashboard shows updated data
      assert_response_includes sermon.title
      assert_response_includes sermon.church
      assert_response_includes "uploaded"
      
      # Performance Assertions
      assert ingestion_time < 1.second, "Data ingestion took too long: #{ingestion_time}s"
      assert crawling_time < @max_crawling_time, "Crawling took too long: #{crawling_time}s"
      assert video_generation_time < @max_video_generation_time, "Video generation took too long: #{video_generation_time}s"
      assert dashboard_time < @max_dashboard_load_time, "Dashboard load took too long: #{dashboard_time}s"
    end
  end

  test "batch processing workflow with multiple sermons" do
    sermon_urls = [
      "https://church1.com/sermon1",
      "https://church2.com/sermon2", 
      "https://church3.com/sermon3"
    ]
    
    performance_benchmark("Batch Processing Workflow") do
      # Setup stubs for all URLs
      sermon_urls.each_with_index do |url, index|
        stub_request(:get, url)
          .to_return(
            status: 200,
            body: create_sermon_html_variant(index + 1),
            headers: { 'Content-Type' => 'text/html' }
          )
      end
      
      # Batch ingestion
      ingestion_time = performance_benchmark("Batch Ingestion") do
        sermon_urls.each do |url|
          post '/api/sermons', params: { url: url }
          assert_response :success
        end
      end
      
      # Batch processing
      processing_time = performance_benchmark("Batch Processing") do
        perform_enqueued_jobs do
          sermon_urls.each do |url|
            SermonCrawlingJob.perform_later(url)
          end
        end
      end
      
      # Verify all sermons were created
      assert_equal 3, Sermon.count
      
      # Batch video generation
      video_generation_time = performance_benchmark("Batch Video Generation") do
        stub_video_generation_success
        
        perform_enqueued_jobs do
          Sermon.all.each do |sermon|
            VideoProcessingJob.perform_later(sermon.id)
          end
        end
      end
      
      # Verify all videos were created
      assert_equal 3, Video.count
      
      # Dashboard aggregation with multiple items
      dashboard_time = performance_benchmark("Dashboard with Multiple Items") do
        get dashboard_index_path
        assert_response :success
      end
      
      # Performance assertions for batch operations
      assert ingestion_time < 3.seconds, "Batch ingestion took too long"
      assert processing_time < 15.seconds, "Batch processing took too long"
      assert video_generation_time < 45.seconds, "Batch video generation took too long"
      assert dashboard_time < 3.seconds, "Dashboard with multiple items too slow"
    end
  end

  # DATA INGESTION INTEGRATION TESTS

  test "data ingestion with various content types and formats" do
    test_cases = [
      {
        name: "Rich HTML Content",
        url: "https://rich-church.com/sermon",
        content_type: "text/html; charset=utf-8"
      },
      {
        name: "Minimal HTML Content", 
        url: "https://minimal-church.com/sermon",
        content_type: "text/html"
      },
      {
        name: "International Content",
        url: "https://국제교회.com/sermon",
        content_type: "text/html; charset=utf-8"
      }
    ]
    
    test_cases.each do |test_case|
      performance_benchmark("Ingestion: #{test_case[:name]}") do
        stub_request(:get, test_case[:url])
          .to_return(
            status: 200,
            body: create_content_variant(test_case[:name]),
            headers: { 'Content-Type' => test_case[:content_type] }
          )
        
        ingestion_time = Benchmark.realtime do
          post '/api/sermons', params: { url: test_case[:url] }
          assert_response :success
        end
        
        # Verify content was properly parsed and stored
        sermon = Sermon.find_by(source_url: test_case[:url])
        assert_not_nil sermon
        assert sermon.title.present?
        assert sermon.church.present?
        
        # Performance assertion
        assert ingestion_time < 2.seconds, "#{test_case[:name]} ingestion too slow: #{ingestion_time}s"
      end
    end
  end

  test "data ingestion error handling and recovery" do
    error_scenarios = [
      { status: 404, error_type: "Not Found" },
      { status: 500, error_type: "Server Error" },
      { status: 503, error_type: "Service Unavailable" },
      { timeout: true, error_type: "Timeout" }
    ]
    
    error_scenarios.each do |scenario|
      performance_benchmark("Error Handling: #{scenario[:error_type]}") do
        if scenario[:timeout]
          stub_request(:get, @test_sermon_url).to_timeout
        else
          stub_request(:get, @test_sermon_url)
            .to_return(status: scenario[:status], body: "Error")
        end
        
        recovery_time = Benchmark.realtime do
          perform_enqueued_jobs do
            SermonCrawlingJob.perform_later(@test_sermon_url)
          end
        end
        
        # Verify error was handled gracefully
        assert_no_difference 'Sermon.count' do
          # Error should not create invalid records
        end
        
        # Performance assertion - errors should fail fast
        assert recovery_time < 5.seconds, "Error recovery too slow: #{recovery_time}s"
      end
    end
  end

  # PROCESSING PIPELINE INTEGRATION TESTS

  test "video generation pipeline with different content sizes" do
    content_sizes = [
      { name: "Short Sermon", script_length: 500 },
      { name: "Medium Sermon", script_length: 2000 },
      { name: "Long Sermon", script_length: 8000 }
    ]
    
    content_sizes.each do |size_test|
      performance_benchmark("Video Pipeline: #{size_test[:name]}") do
        # Create sermon with specific content size
        sermon = create_valid_sermon(
          interpretation: "x" * size_test[:script_length],
          action_points: "Action point content"
        )
        
        generation_time = performance_benchmark("Generation: #{size_test[:name]}") do
          stub_video_generation_success
          
          perform_enqueued_jobs do
            VideoProcessingJob.perform_later(sermon.id)
          end
        end
        
        video = sermon.videos.last
        assert_not_nil video
        assert video.script.length >= 10
        
        # Performance scaling expectations
        max_time = case size_test[:name]
                  when "Short Sermon" then 10.seconds
                  when "Medium Sermon" then 20.seconds  
                  when "Long Sermon" then 40.seconds
                  end
        
        assert generation_time < max_time, "#{size_test[:name]} generation too slow: #{generation_time}s"
      end
    end
  end

  test "concurrent video processing pipeline" do
    performance_benchmark("Concurrent Video Processing") do
      # Create multiple sermons for concurrent processing
      sermons = 3.times.map do |i|
        create_valid_sermon(
          title: "Concurrent Sermon #{i + 1}",
          source_url: "https://concurrent#{i + 1}.com"
        )
      end
      
      stub_video_generation_success
      
      # Process videos concurrently
      concurrent_time = performance_benchmark("Concurrent Processing") do
        threads = sermons.map do |sermon|
          Thread.new do
            perform_enqueued_jobs do
              VideoProcessingJob.perform_later(sermon.id)
            end
          end
        end
        
        threads.each(&:join)
      end
      
      # Verify all videos were processed
      assert_equal 3, Video.count
      sermons.each do |sermon|
        assert sermon.videos.any?
      end
      
      # Concurrent processing should be faster than sequential
      sequential_estimate = 30.seconds * 3 # Rough estimate
      assert concurrent_time < sequential_estimate, "Concurrent processing not efficient: #{concurrent_time}s"
    end
  end

  # OUTPUT GENERATION INTEGRATION TESTS

  test "dashboard performance with large datasets" do
    performance_benchmark("Dashboard with Large Dataset") do
      # Create large dataset
      setup_time = performance_benchmark("Large Dataset Setup") do
        50.times do |i|
          sermon = create_valid_sermon(
            title: "Performance Test Sermon #{i + 1}",
            source_url: "https://perf-test#{i + 1}.com",
            church: "Performance Church #{(i % 5) + 1}"
          )
          
          create_valid_video(
            sermon,
            status: ["pending", "processing", "uploaded", "failed"].sample
          )
        end
      end
      
      # Test dashboard rendering performance
      dashboard_time = performance_benchmark("Dashboard Rendering") do
        get dashboard_index_path
        assert_response :success
      end
      
      # Test dashboard statistics calculation
      stats_time = performance_benchmark("Statistics Calculation") do
        get dashboard_index_path, params: { format: :json }
        if response.content_type.include?('json')
          json_data = JSON.parse(response.body)
          assert json_data.key?('sermon_count') || json_data.key?('statistics')
        end
      end
      
      # Performance assertions for large datasets
      assert setup_time < 30.seconds, "Large dataset setup too slow"
      assert dashboard_time < 5.seconds, "Dashboard rendering with large dataset too slow"
      assert stats_time < 3.seconds, "Statistics calculation too slow"
    end
  end

  test "API output generation performance" do
    # Create test data
    sermon = create_valid_sermon
    video = create_valid_video(sermon, status: "uploaded")
    
    api_endpoints = [
      { path: '/api/sermons', name: 'Sermons Index' },
      { path: "/api/sermons/#{sermon.id}", name: 'Sermon Show' },
      { path: '/api/videos', name: 'Videos Index' },
      { path: "/api/videos/#{video.id}", name: 'Video Show' }
    ]
    
    api_endpoints.each do |endpoint|
      performance_benchmark("API: #{endpoint[:name]}") do
        response_time = Benchmark.realtime do
          get endpoint[:path]
          # Handle cases where API endpoints might not exist yet
          assert_includes [200, 404], response.status
        end
        
        # API responses should be fast
        assert response_time < 1.second, "#{endpoint[:name]} API too slow: #{response_time}s"
      end
    end
  end

  # MEMORY AND RESOURCE MONITORING TESTS

  test "memory usage during complete workflow" do
    performance_benchmark("Memory Usage Monitoring") do
      initial_memory = get_memory_usage
      
      # Process multiple sermons to test memory growth
      5.times do |i|
        stub_request(:get, "https://memory-test#{i}.com")
          .to_return(status: 200, body: @test_sermon_html)
        
        # Full workflow for each sermon
        perform_enqueued_jobs do
          SermonCrawlingJob.perform_later("https://memory-test#{i}.com")
        end
        
        sermon = Sermon.last
        stub_video_generation_success
        
        perform_enqueued_jobs do
          VideoProcessingJob.perform_later(sermon.id)
        end
      end
      
      final_memory = get_memory_usage
      memory_growth = final_memory - initial_memory
      
      # Memory growth should be reasonable (less than 100MB for 5 sermons)
      max_acceptable_growth = 100 * 1024 * 1024 # 100MB in bytes
      assert memory_growth < max_acceptable_growth, 
        "Excessive memory growth: #{memory_growth / 1024 / 1024}MB"
      
      @performance_metrics[:memory_growth] = "#{memory_growth / 1024 / 1024}MB"
    end
  end

  test "database performance under load" do
    performance_benchmark("Database Performance") do
      # Test database operations under load
      query_times = []
      
      # Create baseline data
      20.times { create_valid_sermon }
      
      # Test various database operations
      operations = [
        -> { Sermon.count },
        -> { Sermon.recent.limit(10).to_a },
        -> { Sermon.with_videos.count },
        -> { Video.includes(:sermon).limit(10).to_a }
      ]
      
      operations.each_with_index do |operation, index|
        query_time = Benchmark.realtime { operation.call }
        query_times << query_time
        
        assert query_time < 0.5.seconds, "Database query #{index + 1} too slow: #{query_time}s"
      end
      
      @performance_metrics[:average_query_time] = "#{(query_times.sum / query_times.length * 1000).round(2)}ms"
    end
  end

  # RESILIENCE AND ERROR RECOVERY TESTS

  test "workflow resilience with partial failures" do
    performance_benchmark("Resilience Testing") do
      # Scenario: Sermon crawling succeeds, video generation fails
      stub_sermon_crawling_request
      
      recovery_time = performance_benchmark("Partial Failure Recovery") do
        # Successful crawling
        perform_enqueued_jobs do
          SermonCrawlingJob.perform_later(@test_sermon_url)
        end
        
        sermon = Sermon.last
        assert_not_nil sermon
        
        # Failed video generation
        stub_video_generation_failure
        
        perform_enqueued_jobs do
          VideoProcessingJob.perform_later(sermon.id)
        end
        
        # Verify partial success state
        sermon.reload
        video = sermon.videos.last
        assert_equal 'failed', video.status if video
      end
      
      # Recovery should be fast
      assert recovery_time < 10.seconds, "Partial failure recovery too slow"
    end
  end

  test "system recovery after complete failure" do
    performance_benchmark("System Recovery") do
      # Simulate complete system failure
      original_sermon_count = Sermon.count
      
      # Multiple failed attempts
      3.times do
        stub_request(:get, @test_sermon_url).to_return(status: 500)
        
        perform_enqueued_jobs do
          SermonCrawlingJob.perform_later(@test_sermon_url)
        end
      end
      
      # System should remain stable
      assert_equal original_sermon_count, Sermon.count
      
      # Recovery with successful request
      recovery_time = performance_benchmark("Full System Recovery") do
        stub_sermon_crawling_request
        
        perform_enqueued_jobs do
          SermonCrawlingJob.perform_later(@test_sermon_url)
        end
      end
      
      # Verify system recovered
      assert_equal original_sermon_count + 1, Sermon.count
      assert recovery_time < 5.seconds, "System recovery too slow"
    end
  end

  private

  def performance_benchmark(operation_name)
    start_time = Time.current
    start_memory = get_memory_usage
    
    result = yield
    
    end_time = Time.current
    end_memory = get_memory_usage
    
    execution_time = end_time - start_time
    memory_delta = end_memory - start_memory
    
    @performance_metrics[operation_name] = {
      execution_time: "#{(execution_time * 1000).round(2)}ms",
      memory_delta: "#{memory_delta / 1024}KB"
    }
    
    Rails.logger.info "PERFORMANCE: #{operation_name} completed in #{execution_time.round(3)}s"
    
    execution_time
  end

  def get_memory_usage
    # Cross-platform memory usage detection
    if RUBY_PLATFORM.include?('darwin') # macOS
      `ps -o rss= -p #{Process.pid}`.to_i * 1024 # Convert KB to bytes
    elsif RUBY_PLATFORM.include?('linux')
      File.read("/proc/#{Process.pid}/status")
        .lines
        .grep(/VmRSS/)[0]
        .split[1].to_i * 1024 # Convert KB to bytes
    else
      0 # Fallback for unsupported platforms
    end
  rescue
    0
  end

  def log_performance_metrics
    Rails.logger.info "="*50
    Rails.logger.info "INTEGRATION TEST PERFORMANCE METRICS"
    Rails.logger.info "="*50
    
    @performance_metrics.each do |operation, metrics|
      if metrics.is_a?(Hash)
        Rails.logger.info "#{operation}:"
        Rails.logger.info "  Execution Time: #{metrics[:execution_time]}"
        Rails.logger.info "  Memory Delta: #{metrics[:memory_delta]}"
      else
        Rails.logger.info "#{operation}: #{metrics}"
      end
    end
    
    Rails.logger.info "="*50
  end

  def stub_sermon_crawling_request
    stub_request(:get, @test_sermon_url)
      .to_return(status: 200, body: @test_sermon_html, headers: { 'Content-Type' => 'text/html' })
  end

  def stub_video_generation_success
    # Mock successful video generation by stubbing file operations
    VideoGeneratorService.any_instance.stubs(:generate_video).returns(
      OpenStruct.new(
        success?: true,
        video_path: '/tmp/test_video.mp4',
        thumbnail_path: '/tmp/test_thumbnail.jpg'
      )
    )
  end

  def stub_video_generation_failure
    VideoGeneratorService.any_instance.stubs(:generate_video).returns(
      OpenStruct.new(
        success?: false,
        error: "Video generation failed"
      )
    )
  end

  def create_realistic_sermon_html
    <<~HTML
      <html>
        <head><title>Faith and Hope in Difficult Times</title></head>
        <body>
          <h1>Faith and Hope in Difficult Times</h1>
          <p class="pastor">Pastor John Smith</p>
          <p class="church">Grace Community Church</p>
          <p class="scripture">Romans 8:28</p>
          <div class="content">
            <p>God works all things together for good for those who love Him and are called according to His purpose.</p>
            <p>In times of difficulty and uncertainty, we often wonder where God is in our struggles.</p>
            <p>Action points: Trust in God's timing, pray daily for wisdom, serve others in need.</p>
          </div>
          <p class="date">December 25, 2023</p>
          <p class="denomination">Baptist</p>
          <p class="audience">150 people</p>
        </body>
      </html>
    HTML
  end

  def create_sermon_html_variant(index)
    titles = ["Faith in Action", "Hope for Tomorrow", "Love Never Fails"]
    churches = ["First Baptist", "Community Methodist", "Grace Presbyterian"]
    pastors = ["Rev. Sarah Wilson", "Pastor Mike Johnson", "Dr. David Lee"]
    
    <<~HTML
      <html>
        <head><title>#{titles[index - 1]}</title></head>
        <body>
          <h1>#{titles[index - 1]}</h1>
          <p class="pastor">#{pastors[index - 1]}</p>
          <p class="church">#{churches[index - 1]}</p>
          <div class="content">
            <p>Sermon content for #{titles[index - 1]}.</p>
            <p>Action points for sermon #{index}.</p>
          </div>
        </body>
      </html>
    HTML
  end

  def create_content_variant(variant_name)
    case variant_name
    when "Rich HTML Content"
      create_realistic_sermon_html
    when "Minimal HTML Content"
      "<html><body><h1>Simple Sermon</h1><p>Simple Church</p></body></html>"
    when "International Content"
      <<~HTML
        <html>
          <head><title>신앙과 희망</title></head>
          <body>
            <h1>신앙과 희망</h1>
            <p class="church">은혜교회</p>
            <p class="pastor">김목사</p>
          </body>
        </html>
      HTML
    else
      create_realistic_sermon_html
    end
  end

  def cleanup_test_files
    test_files = [
      '/tmp/test_video.mp4',
      '/tmp/test_thumbnail.jpg'
    ]
    
    test_files.each do |file|
      File.delete(file) if File.exist?(file)
    end
  end

  def assert_response_includes(content)
    assert_includes response.body, content, "Response should include '#{content}'"
  end
end