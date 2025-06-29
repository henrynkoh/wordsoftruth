# Performance Profiler for Words of Truth Core Algorithms
# 
# Usage:
#   PerformanceProfiler.profile_sermon_crawler
#   PerformanceProfiler.profile_video_generator
#   PerformanceProfiler.profile_search_algorithms
#   PerformanceProfiler.profile_dashboard_stats

# Only load profiling gems in development/test environments
if Rails.env.development? || Rails.env.test?
  require 'ruby-prof'
  require 'stackprof'
  require 'memory_profiler'
end
require 'benchmark'
require 'ostruct'

class PerformanceProfiler
  PROFILE_DIR = Rails.root.join('tmp', 'performance_profiles')
  
  class << self
    def profiling_available?
      Rails.env.development? || Rails.env.test?
    end
    
    def setup_profiling_environment
      return unless profiling_available?
      FileUtils.mkdir_p(PROFILE_DIR)
      puts "Performance profiling setup complete. Reports saved to: #{PROFILE_DIR}"
    end

    # Profile SermonCrawlerService core algorithms
    def profile_sermon_crawler(iterations: 10, sample_size: 100)
      return puts "Profiling only available in development/test environments" unless profiling_available?
      setup_profiling_environment
      puts "\n=== Profiling SermonCrawlerService ==="
      
      # Setup test data
      sample_urls = generate_sample_church_urls(sample_size)
      
      # Profile with StackProf (sampling profiler)
      stackprof_profile('sermon_crawler_stackprof') do
        iterations.times do |i|
          puts "Iteration #{i + 1}/#{iterations}"
          sample_urls.each_with_index do |url, idx|
            config = { 'url' => url, 'selectors' => default_selectors }
            service = SermonCrawlerService.new("test_church_#{idx}", config)
            # Mock external HTTP calls for consistent profiling
            mock_http_response_for_profiling(service)
            service.crawl
          end
        end
      end
      
      # Profile with RubyProf (deterministic profiler)
      rubyprof_profile('sermon_crawler_rubyprof', RubyProf::WALL_TIME) do
        5.times do # Fewer iterations for deterministic profiling
          sample_urls.first(10).each_with_index do |url, idx|
            config = { 'url' => url, 'selectors' => default_selectors }
            service = SermonCrawlerService.new("test_church_#{idx}", config)
            mock_http_response_for_profiling(service)
            service.crawl
          end
        end
      end
      
      # Memory profiling
      memory_profile('sermon_crawler_memory') do
        sample_urls.first(20).each_with_index do |url, idx|
          config = { 'url' => url, 'selectors' => default_selectors }
          service = SermonCrawlerService.new("test_church_#{idx}", config)
          mock_http_response_for_profiling(service)
          service.crawl
        end
      end
    end

    # Profile VideoGeneratorService algorithms
    def profile_video_generator(iterations: 5, video_count: 50)
      return puts "Profiling only available in development/test environments" unless profiling_available?
      setup_profiling_environment
      puts "\n=== Profiling VideoGeneratorService ==="
      
      # Setup test videos with varying script lengths
      test_videos = create_test_videos_for_profiling(video_count)
      
      stackprof_profile('video_generator_stackprof') do
        iterations.times do |i|
          puts "Video Generation Iteration #{i + 1}/#{iterations}"
          test_videos.each do |video|
            service = VideoGeneratorService.new(video)
            # Mock external file operations for consistent profiling
            mock_video_operations_for_profiling(service)
            service.generate
          end
        end
      end
      
      rubyprof_profile('video_generator_rubyprof', RubyProf::WALL_TIME) do
        test_videos.first(10).each do |video|
          service = VideoGeneratorService.new(video)
          mock_video_operations_for_profiling(service)
          service.generate
        end
      end
      
      memory_profile('video_generator_memory') do
        test_videos.first(15).each do |video|
          service = VideoGeneratorService.new(video)
          mock_video_operations_for_profiling(service)
          service.generate
        end
      end
    end

    # Profile search algorithms
    def profile_search_algorithms(dataset_size: 1000, query_count: 100)
      setup_profiling_environment
      puts "\n=== Profiling Search Algorithms ==="
      
      # Create large dataset for search testing
      create_search_test_dataset(dataset_size)
      search_queries = generate_search_queries(query_count)
      
      stackprof_profile('search_algorithms_stackprof') do
        search_queries.each_with_index do |query, i|
          puts "Search Query #{i + 1}/#{query_count}" if i % 20 == 0
          Sermon.search(query)
        end
      end
      
      rubyprof_profile('search_algorithms_rubyprof', RubyProf::WALL_TIME) do
        search_queries.first(20).each do |query|
          Sermon.search(query)
        end
      end
      
      # Profile database query performance
      benchmark_search_queries(search_queries.first(50))
    end

    # Profile dashboard statistics calculation
    def profile_dashboard_stats(iterations: 20)
      setup_profiling_environment
      puts "\n=== Profiling Dashboard Statistics ==="
      
      # Ensure we have substantial data for meaningful profiling
      ensure_dashboard_test_data
      
      stackprof_profile('dashboard_stats_stackprof') do
        iterations.times do |i|
          puts "Dashboard Stats Iteration #{i + 1}/#{iterations}"
          controller = DashboardController.new
          controller.send(:calculate_dashboard_stats)
        end
      end
      
      rubyprof_profile('dashboard_stats_rubyprof', RubyProf::WALL_TIME) do
        5.times do
          controller = DashboardController.new
          controller.send(:calculate_dashboard_stats)
        end
      end
      
      # Benchmark individual stat calculations
      benchmark_individual_dashboard_stats
    end

    # Profile video batch processing
    def profile_video_batch_processing(batch_size: 100, video_count: 500)
      setup_profiling_environment
      puts "\n=== Profiling Video Batch Processing ==="
      
      # Create videos for batch processing
      create_videos_for_batch_profiling(video_count)
      
      stackprof_profile('video_batch_processing_stackprof') do
        VideoProcessingJob.new.perform(batch_size)
      end
      
      rubyprof_profile('video_batch_processing_rubyprof', RubyProf::WALL_TIME) do
        VideoProcessingJob.new.perform(50) # Smaller batch for deterministic profiling
      end
      
      memory_profile('video_batch_processing_memory') do
        VideoProcessingJob.new.perform(batch_size)
      end
    end

    private

    def stackprof_profile(name, &block)
      puts "Running StackProf analysis for #{name}..."
      StackProf.run(mode: :wall, out: "#{PROFILE_DIR}/#{name}.dump") do
        yield
      end
      puts "StackProf profile saved: #{name}.dump"
    end

    def rubyprof_profile(name, measure_mode = RubyProf::WALL_TIME, &block)
      puts "Running RubyProf analysis for #{name}..."
      RubyProf.measure_mode = measure_mode
      result = RubyProf.profile(&block)
      
      # Generate multiple report formats
      File.open("#{PROFILE_DIR}/#{name}_flat.txt", 'w') do |file|
        RubyProf::FlatPrinter.new(result).print(file)
      end
      
      File.open("#{PROFILE_DIR}/#{name}_graph.txt", 'w') do |file|
        RubyProf::GraphPrinter.new(result).print(file)
      end
      
      File.open("#{PROFILE_DIR}/#{name}_call_stack.html", 'w') do |file|
        RubyProf::CallStackPrinter.new(result).print(file)
      end
      
      puts "RubyProf profiles saved: #{name}_*.{txt,html}"
    end

    def memory_profile(name, &block)
      puts "Running Memory Profiler analysis for #{name}..."
      report = MemoryProfiler.report(&block)
      report.pretty_print(to_file: "#{PROFILE_DIR}/#{name}_memory.txt")
      puts "Memory profile saved: #{name}_memory.txt"
    end

    def generate_sample_church_urls(count)
      (1..count).map do |i|
        "https://example-church-#{i}.com/sermons"
      end
    end

    def default_selectors
      {
        'sermon' => '.sermon',
        'title' => '.title',
        'pastor' => '.pastor', 
        'date' => '.date',
        'scripture' => '.scripture',
        'interpretation' => '.interpretation',
        'audience_count' => '.audience-count'
      }
    end

    def mock_http_response_for_profiling(service)
      # Mock HTTP responses to focus on parsing/processing logic
      html_content = generate_sample_sermon_html
      service.instance_variable_set(:@response_body, html_content)
    end

    def generate_sample_sermon_html
      # Generate realistic HTML for profiling parsing algorithms
      sermons = (1..50).map do |i|
        <<~HTML
          <div class="sermon" id="sermon-#{i}">
            <h3 class="title">Sample Sermon Title #{i}</h3>
            <div class="pastor">Pastor Name #{i}</div>
            <div class="date">2024-#{sprintf('%02d', (i % 12) + 1)}-#{sprintf('%02d', (i % 28) + 1)}</div>
            <div class="scripture">John #{i}:#{i % 20 + 1}-#{i % 20 + 10}</div>
            <div class="interpretation">This is a sample interpretation for sermon #{i}. It contains meaningful content for parsing and processing algorithms to work with during performance testing.</div>
            <div class="audience-count">#{rand(50..500)}</div>
          </div>
        HTML
      end
      
      <<~HTML
        <!DOCTYPE html>
        <html>
        <body>
          <div class="sermons-container">
            #{sermons.join("\n")}
          </div>
        </body>
        </html>
      HTML
    end

    def create_test_videos_for_profiling(count)
      (1..count).map do |i|
        script_length = [500, 1500, 3000, 5000].sample
        script_content = "Sample script content for video #{i}. " * (script_length / 50)
        
        OpenStruct.new(
          id: i,
          script: script_content[0, script_length],
          status: 'approved'
        )
      end
    end

    def mock_video_operations_for_profiling(service)
      # Mock file operations to focus on algorithmic performance
      service.define_singleton_method(:create_temp_directory) { "/tmp/mock_dir_#{rand(1000)}" }
      service.define_singleton_method(:cleanup_temp_files) { true }
    end

    def create_search_test_dataset(size)
      return if Sermon.count >= size
      
      puts "Creating search test dataset (#{size} sermons)..."
      (Sermon.count + 1..size).each do |i|
        Sermon.create!(
          title: "Test Sermon #{i}: #{Faker::Lorem.sentence}",
          pastor: Faker::Name.name,
          scripture: "#{['Genesis', 'Exodus', 'Matthew', 'John', 'Romans'].sample} #{rand(1..50)}:#{rand(1..30)}",
          interpretation: Faker::Lorem.paragraph(sentence_count: rand(5..15)),
          source_url: "https://example.com/sermon-#{i}",
          church: "Test Church #{i % 20 + 1}",
          denomination: ['Presbyterian', 'Baptist', 'Methodist', 'Lutheran'].sample,
          audience_count: rand(20..1000)
        )
      end
    end

    def generate_search_queries(count)
      keywords = ['love', 'faith', 'hope', 'grace', 'salvation', 'prayer', 'worship', 'service', 'community', 'peace']
      pastors = ['Smith', 'Johnson', 'Williams', 'Brown', 'Jones']
      scriptures = ['John', 'Matthew', 'Romans', 'Genesis', 'Psalms']
      
      (1..count).map do
        case rand(4)
        when 0
          keywords.sample
        when 1
          pastors.sample
        when 2
          scriptures.sample
        else
          "#{keywords.sample} #{scriptures.sample}"
        end
      end
    end

    def benchmark_search_queries(queries)
      puts "\nBenchmarking search query performance:"
      queries.each_slice(10) do |query_batch|
        time = Benchmark.realtime do
          query_batch.each { |query| Sermon.search(query) }
        end
        puts "Batch of 10 queries: #{(time * 1000).round(2)}ms"
      end
    end

    def ensure_dashboard_test_data
      # Ensure we have enough data for meaningful dashboard profiling
      create_search_test_dataset(500) if Sermon.count < 500
      
      # Create videos if needed
      if Video.count < 200
        puts "Creating video test data for dashboard profiling..."
        Sermon.limit(200).each do |sermon|
          Video.create!(
            sermon: sermon,
            script: "Test script for #{sermon.title}",
            status: ['pending', 'approved', 'processing', 'uploaded', 'failed'].sample
          )
        end
      end
    end

    def benchmark_individual_dashboard_stats
      puts "\nBenchmarking individual dashboard statistics:"
      
      stats = {
        'Total Sermons' => -> { Sermon.count },
        'Total Videos' => -> { Video.count },
        'Approved Videos' => -> { Video.approved.count },
        'Processing Videos' => -> { Video.processing.count },
        'Recent Sermons (30 days)' => -> { Sermon.recent.count },
        'Uploaded Videos' => -> { Video.uploaded.count }
      }
      
      stats.each do |name, query|
        time = Benchmark.realtime { 3.times { query.call } }
        puts "#{name}: #{(time * 1000 / 3).round(2)}ms avg"
      end
    end

    def create_videos_for_batch_profiling(count)
      return if Video.count >= count
      
      puts "Creating videos for batch processing profiling..."
      ensure_dashboard_test_data # Ensure we have sermons
      
      sermons = Sermon.limit(count)
      sermons.each_with_index do |sermon, i|
        Video.find_or_create_by(sermon: sermon) do |video|
          video.script = "Batch processing test script #{i}"
          video.status = 'approved'
        end
      end
    end
  end
end