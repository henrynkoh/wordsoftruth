require "test_helper"

# Integration Test Helper Module
# Provides common utilities and configurations for integration testing
module IntegrationTestHelper
  extend ActiveSupport::Concern

  # Performance monitoring configuration
  PERFORMANCE_CONFIG = {
    # Business workflow thresholds
    complete_workflow: 45.seconds,
    sermon_ingestion: 10.seconds,
    video_generation: 30.seconds,
    dashboard_response: 2.seconds,
    
    # API performance thresholds
    api_response: 1.second,
    api_batch_operation: 5.seconds,
    api_concurrent_users: 3.seconds,
    
    # Database performance thresholds
    simple_query: 100.milliseconds,
    complex_query: 500.milliseconds,
    aggregation_query: 1.second,
    
    # Memory usage limits
    max_memory_per_operation: 50.megabytes,
    max_total_memory_growth: 200.megabytes,
    
    # Scalability limits
    max_concurrent_users: 10,
    max_batch_size: 100,
    max_dataset_size: 1000
  }.freeze

  included do
    def setup
      super
      @performance_tracker = PerformanceTracker.new
      @memory_tracker = MemoryTracker.new
      setup_integration_test_environment
    end

    def teardown
      cleanup_integration_test_environment
      @performance_tracker.generate_report if @performance_tracker
      super
    end
  end

  # Performance tracking utilities
  class PerformanceTracker
    def initialize
      @operations = {}
      @start_time = Time.current
    end

    def track(operation_name)
      start_time = Time.current
      start_memory = get_memory_usage
      
      result = yield
      
      end_time = Time.current
      end_memory = get_memory_usage
      
      @operations[operation_name] = {
        duration: end_time - start_time,
        memory_delta: end_memory - start_memory,
        timestamp: start_time
      }
      
      result
    end

    def generate_report
      return if @operations.empty?
      
      Rails.logger.info "\n" + "="*70
      Rails.logger.info "INTEGRATION TEST PERFORMANCE REPORT"
      Rails.logger.info "="*70
      Rails.logger.info "Total test duration: #{(Time.current - @start_time).round(2)}s"
      Rails.logger.info "Operations tracked: #{@operations.count}"
      Rails.logger.info "-"*70
      
      @operations.each do |operation, metrics|
        Rails.logger.info sprintf("%-40s %8.2fms %8s", 
          operation, 
          metrics[:duration] * 1000,
          format_memory(metrics[:memory_delta])
        )
      end
      
      Rails.logger.info "="*70
    end

    private

    def get_memory_usage
      if RUBY_PLATFORM.include?('darwin')
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
      if bytes.abs > 1024 * 1024
        "#{(bytes / 1024.0 / 1024.0).round(1)}MB"
      elsif bytes.abs > 1024
        "#{(bytes / 1024.0).round(1)}KB"
      else
        "#{bytes}B"
      end
    end
  end

  # Memory tracking utilities
  class MemoryTracker
    def initialize
      @initial_memory = get_memory_usage
      @peak_memory = @initial_memory
      @operations = []
    end

    def checkpoint(operation_name)
      current_memory = get_memory_usage
      @peak_memory = [current_memory, @peak_memory].max
      
      @operations << {
        name: operation_name,
        memory: current_memory,
        delta_from_initial: current_memory - @initial_memory,
        timestamp: Time.current
      }
    end

    def total_growth
      get_memory_usage - @initial_memory
    end

    def peak_usage
      @peak_memory - @initial_memory
    end

    private

    def get_memory_usage
      if RUBY_PLATFORM.include?('darwin')
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
  end

  # Test data factories for integration testing
  module TestDataFactory
    def create_realistic_sermon_dataset(size = 10)
      churches = [
        "Grace Community Church", "First Baptist Church", "Hope Presbyterian",
        "Faith Assembly", "New Life Methodist", "Cornerstone Fellowship",
        "Trinity Lutheran", "Calvary Chapel", "Emmanuel Episcopal", "Unity Church"
      ]
      
      pastors = [
        "Pastor John Smith", "Rev. Sarah Johnson", "Dr. Michael Brown",
        "Pastor Lisa Chen", "Rev. David Williams", "Dr. Mary Davis",
        "Pastor Robert Miller", "Rev. Jennifer Wilson", "Dr. James Taylor", "Pastor Rachel Moore"
      ]
      
      denominations = [
        "Baptist", "Methodist", "Presbyterian", "Pentecostal", "Lutheran",
        "Episcopal", "Non-denominational", "Assembly of God", "Catholic", "Orthodox"
      ]
      
      size.times do |i|
        create_valid_sermon(
          title: generate_sermon_title(i),
          source_url: "https://integration-test-#{i}.com/sermon",
          church: churches[i % churches.length],
          pastor: pastors[i % pastors.length],
          denomination: denominations[i % denominations.length],
          scripture: generate_scripture_reference,
          interpretation: generate_sermon_content(:interpretation),
          action_points: generate_sermon_content(:action_points),
          sermon_date: rand(365).days.ago,
          audience_count: rand(50..500)
        )
      end
    end

    def create_video_processing_dataset(sermon_count = 5)
      sermons = create_realistic_sermon_dataset(sermon_count)
      
      sermons.each_with_index do |sermon, index|
        status = case index % 4
                when 0 then "pending"
                when 1 then "processing"
                when 2 then "uploaded"
                else "failed"
                end
        
        create_valid_video(
          sermon,
          status: status,
          script: generate_video_script(sermon),
          video_path: status.in?(["uploaded", "processing"]) ? "/storage/videos/test_#{index}.mp4" : nil,
          thumbnail_path: status == "uploaded" ? "/storage/thumbnails/test_#{index}.jpg" : nil,
          youtube_id: status == "uploaded" ? "TEST#{index}ABC" : nil
        )
      end
      
      sermons
    end

    private

    def generate_sermon_title(index)
      themes = [
        "Faith in Difficult Times", "Hope for Tomorrow", "Love Never Fails",
        "Walking in the Spirit", "God's Unfailing Grace", "Living with Purpose",
        "Finding Peace", "Strength in Weakness", "Joy in the Journey", "Trust and Obey"
      ]
      
      "#{themes[index % themes.length]} (Part #{(index / themes.length) + 1})"
    end

    def generate_scripture_reference
      books = ["Matthew", "Mark", "Luke", "John", "Romans", "1 Corinthians", "Ephesians", "Philippians"]
      book = books.sample
      chapter = rand(1..20)
      verse = rand(1..30)
      
      "#{book} #{chapter}:#{verse}"
    end

    def generate_sermon_content(type)
      base_content = case type
                    when :interpretation
                      "This passage teaches us about God's character and His relationship with His people. " +
                      "We see themes of love, grace, redemption, and hope throughout Scripture. " +
                      "The context reveals important truths about living as followers of Christ in today's world."
                    when :action_points
                      "1. Spend time in daily prayer and Scripture reading. " +
                      "2. Seek opportunities to serve others in your community. " +
                      "3. Practice forgiveness and grace in your relationships. " +
                      "4. Trust God's plan even when circumstances are difficult."
                    end
      
      # Vary content length for realistic testing
      multiplier = rand(2..8)
      (base_content + " ") * multiplier
    end

    def generate_video_script(sermon)
      <<~SCRIPT
        Welcome to #{sermon.church}. Today we're exploring the message: #{sermon.title}.

        Our Scripture comes from #{sermon.scripture}.

        #{sermon.interpretation.first(500)}

        Key takeaways for this week:
        #{sermon.action_points}

        Thank you for joining us today. May God bless you as you apply these truths to your life.
      SCRIPT
    end
  end

  # HTTP request stubbing helpers
  module RequestStubHelpers
    def stub_successful_sermon_crawling(url, sermon_data = {})
      default_data = {
        title: "Integration Test Sermon",
        church: "Test Church",
        pastor: "Test Pastor"
      }
      
      data = default_data.merge(sermon_data)
      html_content = create_sermon_html(data)
      
      stub_request(:get, url)
        .to_return(
          status: 200,
          body: html_content,
          headers: { 'Content-Type' => 'text/html' }
        )
    end

    def stub_failed_sermon_crawling(url, status = 500)
      stub_request(:get, url)
        .to_return(status: status, body: "Server Error")
    end

    def stub_slow_sermon_crawling(url, delay = 5.seconds)
      stub_request(:get, url)
        .to_return(status: 200, body: create_sermon_html({}))
        .to_timeout.then
        .to_return(status: 200, body: create_sermon_html({}))
    end

    def stub_video_generation_success
      VideoGeneratorService.any_instance.stubs(:generate_video).returns(
        OpenStruct.new(
          success?: true,
          video_path: Rails.root.join('tmp', 'integration_test_video.mp4').to_s,
          thumbnail_path: Rails.root.join('tmp', 'integration_test_thumbnail.jpg').to_s
        )
      )
    end

    def stub_video_generation_failure
      VideoGeneratorService.any_instance.stubs(:generate_video).returns(
        OpenStruct.new(
          success?: false,
          error: "Video generation failed in integration test"
        )
      )
    end

    private

    def create_sermon_html(data)
      <<~HTML
        <html>
          <head><title>#{data[:title] || 'Test Sermon'}</title></head>
          <body>
            <h1>#{data[:title] || 'Test Sermon'}</h1>
            <p class="church">#{data[:church] || 'Test Church'}</p>
            <p class="pastor">#{data[:pastor] || 'Test Pastor'}</p>
            <p class="scripture">#{data[:scripture] || 'Test 1:1'}</p>
            <div class="content">
              <p>#{data[:interpretation] || 'Test sermon content for integration testing.'}</p>
              <p>#{data[:action_points] || 'Test action points for integration testing.'}</p>
            </div>
            <p class="date">#{data[:date] || Date.current}</p>
            <p class="denomination">#{data[:denomination] || 'Test Denomination'}</p>
            <p class="audience">#{data[:audience_count] || 100} people</p>
          </body>
        </html>
      HTML
    end
  end

  # Performance assertion helpers
  module PerformanceAssertions
    def assert_performance_within(threshold, message = nil)
      start_time = Time.current
      result = yield
      actual_time = Time.current - start_time
      
      message ||= "Operation exceeded performance threshold: #{actual_time.round(3)}s > #{threshold.round(3)}s"
      assert actual_time <= threshold, message
      
      result
    end

    def assert_memory_within(threshold)
      initial_memory = get_current_memory
      yield
      final_memory = get_current_memory
      memory_growth = final_memory - initial_memory
      
      assert memory_growth <= threshold, 
        "Memory growth exceeded threshold: #{format_memory(memory_growth)} > #{format_memory(threshold)}"
    end

    def assert_concurrent_performance(user_count, max_total_time)
      start_time = Time.current
      
      threads = user_count.times.map do |i|
        Thread.new { yield(i) }
      end
      
      threads.each(&:join)
      
      total_time = Time.current - start_time
      assert total_time <= max_total_time,
        "Concurrent operation too slow: #{total_time.round(3)}s > #{max_total_time.round(3)}s"
    end

    private

    def get_current_memory
      if RUBY_PLATFORM.include?('darwin')
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
  end

  # Environment setup and cleanup
  def setup_integration_test_environment
    # Clear all data for clean testing
    Video.destroy_all
    Sermon.destroy_all
    
    # Reset ActiveJob queue
    clear_enqueued_jobs
    clear_performed_jobs
    
    # Configure WebMock for integration testing
    WebMock.disable_net_connect!(allow_localhost: true)
    
    # Create tmp directories for test files
    FileUtils.mkdir_p(Rails.root.join('tmp', 'integration_tests'))
    
    # Initialize memory tracking
    @memory_tracker.checkpoint("Test Start") if @memory_tracker
  end

  def cleanup_integration_test_environment
    # Clean up test files
    cleanup_test_files
    
    # Reset WebMock
    WebMock.reset!
    
    # Clear job queues
    clear_enqueued_jobs
    clear_performed_jobs
    
    # Final memory checkpoint
    @memory_tracker.checkpoint("Test End") if @memory_tracker
  end

  def cleanup_test_files
    test_directories = [
      Rails.root.join('tmp', 'integration_tests'),
      Rails.root.join('tmp', 'test_videos'),
      Rails.root.join('tmp', 'test_thumbnails')
    ]
    
    test_directories.each do |dir|
      FileUtils.rm_rf(dir) if Dir.exist?(dir)
    end
    
    # Clean up individual test files
    test_files = Dir.glob(Rails.root.join('tmp', '*integration*'))
    test_files.each { |file| File.delete(file) if File.exist?(file) }
  end

  # Include all helper modules
  include TestDataFactory
  include RequestStubHelpers
  include PerformanceAssertions
end

# Extend ActionDispatch::IntegrationTest with our helpers
ActionDispatch::IntegrationTest.include IntegrationTestHelper