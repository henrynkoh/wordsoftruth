require "test_helper"
require "benchmark"

class PerformanceBenchmarksTest < ActionDispatch::IntegrationTest
  def setup
    # Clear all data for baseline performance testing
    Video.destroy_all
    Sermon.destroy_all
    
    # Performance thresholds based on business requirements
    @performance_thresholds = {
      # Data ingestion should be sub-second for real-time feel
      url_submission: 500.milliseconds,
      content_parsing: 2.seconds,
      data_validation: 100.milliseconds,
      
      # Processing should complete within reasonable time for user experience
      sermon_crawling: 10.seconds,
      video_script_generation: 5.seconds,
      video_processing: 30.seconds,
      
      # UI responsiveness requirements
      dashboard_load: 1.second,
      search_results: 800.milliseconds,
      statistics_calculation: 1.5.seconds,
      
      # Scalability thresholds
      concurrent_users: 5.seconds, # 10 concurrent users
      large_dataset_query: 3.seconds, # 1000+ records
      batch_processing: 60.seconds # 50 items
    }
    
    @performance_results = {}
    @memory_usage = {}
  end

  def teardown
    generate_performance_report
  end

  # BASELINE PERFORMANCE BENCHMARKS

  test "baseline single sermon processing performance" do
    benchmark_suite("Baseline Single Sermon") do
      sermon_url = "https://baseline-church.com/sermon"
      
      # Setup realistic test data
      stub_request(:get, sermon_url)
        .to_return(
          status: 200,
          body: create_performance_test_html,
          headers: { 'Content-Type' => 'text/html' }
        )
      
      # Measure URL submission and validation
      submission_time = measure_operation("URL Submission") do
        post '/api/sermons', params: { url: sermon_url }
        assert_response :success
      end
      assert_performance submission_time, @performance_thresholds[:url_submission]
      
      # Measure content crawling and parsing
      crawling_time = measure_operation("Content Crawling") do
        perform_enqueued_jobs do
          SermonCrawlingJob.perform_later(sermon_url)
        end
      end
      assert_performance crawling_time, @performance_thresholds[:sermon_crawling]
      
      sermon = Sermon.last
      assert_not_nil sermon
      
      # Measure video generation
      video_time = measure_operation("Video Generation") do
        stub_video_generation_for_performance
        perform_enqueued_jobs do
          VideoProcessingJob.perform_later(sermon.id)
        end
      end
      assert_performance video_time, @performance_thresholds[:video_processing]
      
      # Measure dashboard update
      dashboard_time = measure_operation("Dashboard Load") do
        get dashboard_index_path
        assert_response :success
      end
      assert_performance dashboard_time, @performance_thresholds[:dashboard_load]
    end
  end

  test "scalability with increasing dataset sizes" do
    dataset_sizes = [10, 50, 100, 500]
    
    dataset_sizes.each do |size|
      benchmark_suite("Dataset Size: #{size}") do
        # Create dataset
        setup_time = measure_operation("Dataset Setup (#{size} items)") do
          size.times do |i|
            create_valid_sermon(
              title: "Scale Test Sermon #{i + 1}",
              source_url: "https://scale-test#{i}.com",
              church: "Scale Church #{(i % 10) + 1}"
            )
          end
        end
        
        # Test query performance with different dataset sizes
        query_time = measure_operation("Query Performance (#{size} items)") do
          Sermon.includes(:videos).recent.limit(20).to_a
        end
        
        # Test search performance
        search_time = measure_operation("Search Performance (#{size} items)") do
          get dashboard_index_path, params: { search: "Scale" }
          assert_response :success
        end
        
        # Test statistics calculation
        stats_time = measure_operation("Statistics Calculation (#{size} items)") do
          sermon_count = Sermon.count
          video_count = Video.count
          church_count = Sermon.distinct.count(:church)
          
          assert_equal size, sermon_count
        end
        
        # Performance should degrade gracefully with size
        max_query_time = calculate_scalable_threshold(size, @performance_thresholds[:large_dataset_query])
        max_search_time = calculate_scalable_threshold(size, @performance_thresholds[:search_results])
        max_stats_time = calculate_scalable_threshold(size, @performance_thresholds[:statistics_calculation])
        
        assert_performance query_time, max_query_time, "Query performance degraded too much with #{size} items"
        assert_performance search_time, max_search_time, "Search performance degraded too much with #{size} items"
        assert_performance stats_time, max_stats_time, "Statistics calculation too slow with #{size} items"
      end
    end
  end

  test "concurrent user load performance" do
    concurrent_users = [1, 3, 5, 10]
    
    concurrent_users.each do |user_count|
      benchmark_suite("Concurrent Users: #{user_count}") do
        # Setup test data
        user_count.times do |i|
          create_valid_sermon(
            title: "Concurrent Test #{i + 1}",
            source_url: "https://concurrent#{i}.com"
          )
        end
        
        # Simulate concurrent dashboard access
        concurrent_time = measure_operation("Concurrent Dashboard Access (#{user_count} users)") do
          threads = user_count.times.map do |user_id|
            Thread.new do
              individual_time = Benchmark.realtime do
                get dashboard_index_path, params: { user_id: user_id }
                assert_response :success
              end
              individual_time
            end
          end
          
          response_times = threads.map(&:value)
          @performance_results["Individual Response Times (#{user_count} users)"] = 
            "#{(response_times.sum / response_times.length * 1000).round(2)}ms avg, #{(response_times.max * 1000).round(2)}ms max"
        end
        
        # Concurrent access should scale reasonably
        max_concurrent_time = @performance_thresholds[:concurrent_users] * (user_count / 5.0)
        assert_performance concurrent_time, max_concurrent_time, "Concurrent access too slow with #{user_count} users"
        
        # Memory usage should not grow excessively
        memory_after_concurrent = get_memory_usage
        @memory_usage["After #{user_count} concurrent users"] = format_memory(memory_after_concurrent)
      end
    end
  end

  # PROCESSING PIPELINE PERFORMANCE

  test "video generation pipeline performance with various content sizes" do
    content_scenarios = [
      { name: "Short Content", script_size: 500, max_time: 10.seconds },
      { name: "Medium Content", script_size: 2000, max_time: 20.seconds },
      { name: "Long Content", script_size: 8000, max_time: 40.seconds },
      { name: "Very Long Content", script_size: 15000, max_time: 60.seconds }
    ]
    
    content_scenarios.each do |scenario|
      benchmark_suite("Video Pipeline: #{scenario[:name]}") do
        # Create sermon with specific content size
        sermon = create_valid_sermon(
          interpretation: generate_test_content(scenario[:script_size]),
          action_points: "Action points for #{scenario[:name]}"
        )
        
        # Measure script generation
        script_time = measure_operation("Script Generation (#{scenario[:name]})") do
          service = VideoGeneratorService.new(sermon)
          result = service.generate_script
          assert result.success?
        end
        assert_performance script_time, @performance_thresholds[:video_script_generation]
        
        # Measure full video processing
        processing_time = measure_operation("Video Processing (#{scenario[:name]})") do
          stub_video_generation_for_performance
          perform_enqueued_jobs do
            VideoProcessingJob.perform_later(sermon.id)
          end
        end
        assert_performance processing_time, scenario[:max_time], "#{scenario[:name]} processing too slow"
        
        # Verify output quality isn't compromised for performance
        video = sermon.videos.last
        assert_not_nil video
        assert video.script.length >= 10
      end
    end
  end

  test "batch processing performance benchmark" do
    batch_sizes = [5, 10, 25, 50]
    
    batch_sizes.each do |batch_size|
      benchmark_suite("Batch Processing: #{batch_size} items") do
        # Setup batch URLs
        batch_urls = batch_size.times.map { |i| "https://batch#{i}.com/sermon" }
        
        # Stub all batch requests
        batch_urls.each_with_index do |url, index|
          stub_request(:get, url)
            .to_return(
              status: 200,
              body: create_batch_test_html(index + 1),
              headers: { 'Content-Type' => 'text/html' }
            )
        end
        
        # Measure batch submission
        submission_time = measure_operation("Batch Submission (#{batch_size} items)") do
          batch_urls.each do |url|
            post '/api/sermons', params: { url: url }
            assert_response :success
          end
        end
        
        # Measure batch processing
        processing_time = measure_operation("Batch Processing (#{batch_size} items)") do
          perform_enqueued_jobs do
            batch_urls.each do |url|
              SermonCrawlingJob.perform_later(url)
            end
          end
        end
        
        # Measure batch video generation
        video_batch_time = measure_operation("Batch Video Generation (#{batch_size} items)") do
          stub_video_generation_for_performance
          
          perform_enqueued_jobs do
            Sermon.all.each do |sermon|
              VideoProcessingJob.perform_later(sermon.id)
            end
          end
        end
        
        # Verify all items processed
        assert_equal batch_size, Sermon.count
        assert_equal batch_size, Video.count
        
        # Calculate performance thresholds for batch operations
        max_batch_time = @performance_thresholds[:batch_processing] * (batch_size / 10.0)
        assert_performance processing_time, max_batch_time, "Batch processing too slow for #{batch_size} items"
      end
    end
  end

  # MEMORY AND RESOURCE BENCHMARKS

  test "memory usage patterns during heavy processing" do
    benchmark_suite("Memory Usage Analysis") do
      initial_memory = get_memory_usage
      @memory_usage["Initial"] = format_memory(initial_memory)
      
      # Create moderate dataset and measure memory growth
      memory_after_data = measure_memory_operation("Dataset Creation") do
        50.times do |i|
          create_valid_sermon(
            title: "Memory Test #{i + 1}",
            source_url: "https://memory#{i}.com",
            interpretation: generate_test_content(1000)
          )
        end
      end
      
      # Process all sermons and measure memory during processing
      memory_after_processing = measure_memory_operation("Sermon Processing") do
        stub_video_generation_for_performance
        
        perform_enqueued_jobs do
          Sermon.all.each { |sermon| SermonCrawlingJob.perform_later(sermon.source_url) }
          Sermon.all.each { |sermon| VideoProcessingJob.perform_later(sermon.id) }
        end
      end
      
      # Perform memory-intensive dashboard operations
      memory_after_dashboard = measure_memory_operation("Dashboard Operations") do
        10.times do
          get dashboard_index_path
          assert_response :success
        end
      end
      
      # Calculate memory growth
      total_growth = memory_after_dashboard - initial_memory
      processing_growth = memory_after_processing - memory_after_data
      
      @memory_usage["Total Growth"] = format_memory(total_growth)
      @memory_usage["Processing Growth"] = format_memory(processing_growth)
      
      # Memory growth should be reasonable (less than 200MB for this test)
      max_acceptable_growth = 200 * 1024 * 1024 # 200MB
      assert total_growth < max_acceptable_growth, 
        "Excessive memory growth: #{format_memory(total_growth)}"
    end
  end

  test "database query performance optimization" do
    # Create realistic dataset for query testing
    churches = ["Grace Church", "First Baptist", "Community Methodist", "Hope Presbyterian", "Faith Assembly"]
    pastors = ["Pastor Smith", "Rev. Johnson", "Dr. Williams", "Pastor Brown", "Rev. Davis"]
    
    benchmark_suite("Database Query Optimization") do
      # Setup test data with realistic relationships
      setup_time = measure_operation("Database Setup") do
        100.times do |i|
          sermon = create_valid_sermon(
            title: "Query Test Sermon #{i + 1}",
            source_url: "https://query-test#{i}.com",
            church: churches[i % churches.length],
            pastor: pastors[i % pastors.length],
            sermon_date: i.days.ago
          )
          
          # Create videos for some sermons to test joins
          if i % 3 == 0
            create_valid_video(sermon, status: ["pending", "processing", "uploaded"].sample)
          end
        end
      end
      
      # Test various query patterns
      query_tests = [
        {
          name: "Simple Count",
          operation: -> { Sermon.count }
        },
        {
          name: "Recent Sermons",
          operation: -> { Sermon.recent.limit(10).to_a }
        },
        {
          name: "Sermons with Videos",
          operation: -> { Sermon.includes(:videos).with_videos.limit(10).to_a }
        },
        {
          name: "Search by Church",
          operation: -> { Sermon.by_church("Grace Church").to_a }
        },
        {
          name: "Complex Aggregation",
          operation: -> { 
            {
              total_sermons: Sermon.count,
              total_videos: Video.count,
              churches: Sermon.distinct.count(:church),
              recent_count: Sermon.where(created_at: 1.week.ago..).count
            }
          }
        }
      ]
      
      query_tests.each do |test|
        query_time = measure_operation("Query: #{test[:name]}") do
          result = test[:operation].call
          assert_not_nil result
        end
        
        # Database queries should be fast even with larger datasets
        max_query_time = 1.second
        assert_performance query_time, max_query_time, "#{test[:name]} query too slow"
      end
    end
  end

  # ERROR HANDLING PERFORMANCE

  test "error recovery performance impact" do
    benchmark_suite("Error Recovery Performance") do
      # Measure baseline performance
      baseline_time = measure_operation("Baseline Operation") do
        stub_request(:get, "https://baseline.com")
          .to_return(status: 200, body: create_performance_test_html)
        
        perform_enqueued_jobs do
          SermonCrawlingJob.perform_later("https://baseline.com")
        end
      end
      
      # Measure performance with error and recovery
      error_recovery_time = measure_operation("Error Recovery") do
        # First attempt fails
        stub_request(:get, "https://error-test.com")
          .to_return(status: 500).times(2)
          .then.to_return(status: 200, body: create_performance_test_html)
        
        perform_enqueued_jobs do
          SermonCrawlingJob.perform_later("https://error-test.com")
        end
      end
      
      # Recovery should not significantly impact performance
      recovery_overhead = error_recovery_time - baseline_time
      max_acceptable_overhead = 5.seconds
      
      assert recovery_overhead < max_acceptable_overhead,
        "Error recovery overhead too high: #{recovery_overhead}s"
      
      @performance_results["Error Recovery Overhead"] = "#{recovery_overhead.round(2)}s"
    end
  end

  private

  def benchmark_suite(suite_name)
    Rails.logger.info "\n" + "="*60
    Rails.logger.info "PERFORMANCE BENCHMARK SUITE: #{suite_name}"
    Rails.logger.info "="*60
    
    suite_start = Time.current
    initial_memory = get_memory_usage
    
    yield
    
    suite_end = Time.current
    final_memory = get_memory_usage
    
    suite_time = suite_end - suite_start
    memory_delta = final_memory - initial_memory
    
    Rails.logger.info "Suite completed in #{suite_time.round(2)}s, Memory delta: #{format_memory(memory_delta)}"
    Rails.logger.info "="*60
  end

  def measure_operation(operation_name)
    Rails.logger.info "  Measuring: #{operation_name}"
    
    start_time = Time.current
    result = yield
    end_time = Time.current
    
    execution_time = end_time - start_time
    @performance_results[operation_name] = "#{(execution_time * 1000).round(2)}ms"
    
    Rails.logger.info "    #{operation_name}: #{execution_time.round(3)}s"
    
    execution_time
  end

  def measure_memory_operation(operation_name)
    memory_before = get_memory_usage
    yield
    memory_after = get_memory_usage
    
    @memory_usage[operation_name] = format_memory(memory_after - memory_before)
    
    memory_after
  end

  def assert_performance(actual_time, threshold_time, message = nil)
    message ||= "Operation took #{actual_time.round(3)}s, threshold was #{threshold_time.round(3)}s"
    assert actual_time <= threshold_time, message
  end

  def calculate_scalable_threshold(dataset_size, base_threshold)
    # Logarithmic scaling: performance degrades logarithmically with dataset size
    scale_factor = 1 + Math.log10([dataset_size / 10.0, 1].max)
    base_threshold * scale_factor
  end

  def get_memory_usage
    if RUBY_PLATFORM.include?('darwin') # macOS
      `ps -o rss= -p #{Process.pid}`.to_i * 1024
    elsif RUBY_PLATFORM.include?('linux')
      File.read("/proc/#{Process.pid}/status")
        .lines
        .grep(/VmRSS/)[0]
        .split[1].to_i * 1024
    else
      0
    end
  rescue
    0
  end

  def format_memory(bytes)
    if bytes > 1024 * 1024
      "#{(bytes / 1024.0 / 1024.0).round(2)}MB"
    elsif bytes > 1024
      "#{(bytes / 1024.0).round(2)}KB"
    else
      "#{bytes}B"
    end
  end

  def generate_performance_report
    return if @performance_results.empty?
    
    Rails.logger.info "\n" + "#"*80
    Rails.logger.info "PERFORMANCE BENCHMARK REPORT"
    Rails.logger.info "#"*80
    
    Rails.logger.info "\nOPERATION PERFORMANCE:"
    @performance_results.each do |operation, time|
      Rails.logger.info "  #{operation}: #{time}"
    end
    
    if @memory_usage.any?
      Rails.logger.info "\nMEMORY USAGE:"
      @memory_usage.each do |operation, memory|
        Rails.logger.info "  #{operation}: #{memory}"
      end
    end
    
    Rails.logger.info "\nPERFORMANCE THRESHOLDS:"
    @performance_thresholds.each do |operation, threshold|
      Rails.logger.info "  #{operation}: #{(threshold * 1000).round(2)}ms"
    end
    
    Rails.logger.info "#"*80
  end

  def create_performance_test_html
    <<~HTML
      <html>
        <head><title>Performance Test Sermon</title></head>
        <body>
          <h1>Performance Test Sermon</h1>
          <p class="church">Performance Test Church</p>
          <p class="pastor">Performance Pastor</p>
          <p class="scripture">Performance 1:1</p>
          <div class="content">
            <p>#{generate_test_content(500)}</p>
            <p>Action points: Optimize, measure, improve performance.</p>
          </div>
        </body>
      </html>
    HTML
  end

  def create_batch_test_html(index)
    <<~HTML
      <html>
        <head><title>Batch Test Sermon #{index}</title></head>
        <body>
          <h1>Batch Test Sermon #{index}</h1>
          <p class="church">Batch Church #{index}</p>
          <p class="pastor">Batch Pastor #{index}</p>
          <div class="content">
            <p>Batch test content for sermon #{index}.</p>
          </div>
        </body>
      </html>
    HTML
  end

  def generate_test_content(size)
    base_text = "This is test content for performance benchmarking. "
    (base_text * (size / base_text.length + 1))[0...size]
  end

  def stub_video_generation_for_performance
    VideoGeneratorService.any_instance.stubs(:generate_video).returns(
      OpenStruct.new(
        success?: true,
        video_path: '/tmp/perf_test_video.mp4',
        thumbnail_path: '/tmp/perf_test_thumbnail.jpg'
      )
    )
  end
end