# Performance profiling rake tasks for Words of Truth
# 
# Usage:
#   rake performance:profile_all
#   rake performance:sermon_crawler
#   rake performance:video_generator  
#   rake performance:search_algorithms
#   rake performance:dashboard_stats
#   rake performance:batch_processing

namespace :performance do
  desc "Run all performance profiling tasks"
  task profile_all: :environment do
    puts "🚀 Starting comprehensive performance profiling..."
    puts "This will profile all core algorithms under various load conditions."
    puts "Reports will be saved to tmp/performance_profiles/"
    puts "\n" + "="*60
    
    Rake::Task["performance:sermon_crawler"].invoke
    Rake::Task["performance:video_generator"].invoke  
    Rake::Task["performance:search_algorithms"].invoke
    Rake::Task["performance:dashboard_stats"].invoke
    Rake::Task["performance:batch_processing"].invoke
    
    puts "\n" + "="*60
    puts "✅ All performance profiling complete!"
    puts "📊 View reports in tmp/performance_profiles/"
    puts "🔍 Use StackProf viewer: stackprof tmp/performance_profiles/*.dump"
  end

  desc "Profile SermonCrawlerService algorithms"
  task sermon_crawler: :environment do
    puts "🔍 Profiling SermonCrawlerService algorithms..."
    PerformanceProfiler.profile_sermon_crawler(
      iterations: ENV.fetch('ITERATIONS', 10).to_i,
      sample_size: ENV.fetch('SAMPLE_SIZE', 100).to_i
    )
  end

  desc "Profile VideoGeneratorService algorithms"
  task video_generator: :environment do
    puts "🎥 Profiling VideoGeneratorService algorithms..."
    PerformanceProfiler.profile_video_generator(
      iterations: ENV.fetch('ITERATIONS', 5).to_i,
      video_count: ENV.fetch('VIDEO_COUNT', 50).to_i
    )
  end

  desc "Profile search algorithms"
  task search_algorithms: :environment do
    puts "🔎 Profiling search algorithms..."
    PerformanceProfiler.profile_search_algorithms(
      dataset_size: ENV.fetch('DATASET_SIZE', 1000).to_i,
      query_count: ENV.fetch('QUERY_COUNT', 100).to_i
    )
  end

  desc "Profile dashboard statistics calculation"
  task dashboard_stats: :environment do
    puts "📊 Profiling dashboard statistics..."
    PerformanceProfiler.profile_dashboard_stats(
      iterations: ENV.fetch('ITERATIONS', 20).to_i
    )
  end

  desc "Profile video batch processing"
  task batch_processing: :environment do
    puts "⚡ Profiling video batch processing..."
    PerformanceProfiler.profile_video_batch_processing(
      batch_size: ENV.fetch('BATCH_SIZE', 100).to_i,
      video_count: ENV.fetch('VIDEO_COUNT', 500).to_i
    )
  end

  desc "Profile specific scenarios"
  task :scenario, [:scenario_name] => :environment do |t, args|
    scenario = args[:scenario_name]
    
    case scenario
    when 'high_load_crawling'
      puts "🔥 High Load Crawling Scenario"
      PerformanceProfiler.profile_sermon_crawler(iterations: 25, sample_size: 200)
      
    when 'large_dataset_search'
      puts "📚 Large Dataset Search Scenario" 
      PerformanceProfiler.profile_search_algorithms(dataset_size: 5000, query_count: 500)
      
    when 'massive_video_batch'
      puts "🎬 Massive Video Batch Scenario"
      PerformanceProfiler.profile_video_batch_processing(batch_size: 500, video_count: 2000)
      
    when 'concurrent_dashboard'
      puts "⚡ Concurrent Dashboard Load Scenario"
      PerformanceProfiler.profile_dashboard_stats(iterations: 100)
      
    when 'memory_stress'
      puts "🧠 Memory Stress Test Scenario"
      PerformanceProfiler.profile_sermon_crawler(iterations: 50, sample_size: 500)
      PerformanceProfiler.profile_video_generator(iterations: 20, video_count: 200)
      
    else
      puts "❌ Unknown scenario: #{scenario}"
      puts "Available scenarios:"
      puts "  - high_load_crawling"
      puts "  - large_dataset_search" 
      puts "  - massive_video_batch"
      puts "  - concurrent_dashboard"
      puts "  - memory_stress"
      puts "\nUsage: rake performance:scenario[scenario_name]"
    end
  end

  desc "Generate performance report from existing profiles"
  task report: :environment do
    puts "📋 Generating performance analysis report..."
    
    profile_dir = Rails.root.join('tmp', 'performance_profiles')
    unless Dir.exist?(profile_dir)
      puts "❌ No profiles found. Run profiling tasks first."
      exit 1
    end
    
    report_file = profile_dir.join('performance_analysis_report.md')
    
    File.open(report_file, 'w') do |f|
      f.puts "# Words of Truth Performance Analysis Report"
      f.puts "Generated: #{Time.current}"
      f.puts "\n## Profile Files Generated"
      
      Dir.glob("#{profile_dir}/*").each do |file|
        f.puts "- #{File.basename(file)}"
      end
      
      f.puts "\n## Analysis Commands"
      f.puts "### StackProf Analysis"
      f.puts "```bash"
      Dir.glob("#{profile_dir}/*.dump").each do |dump_file|
        f.puts "stackprof #{dump_file} --text"
        f.puts "stackprof #{dump_file} --web"
      end
      f.puts "```"
      
      f.puts "\n### Key Metrics to Analyze"
      f.puts "1. **Total Time** - Overall execution time"
      f.puts "2. **Self Time** - Time spent in method excluding calls"
      f.puts "3. **Memory Allocation** - Objects and memory usage"
      f.puts "4. **Call Count** - Number of method invocations"
      f.puts "5. **Samples** - Distribution of execution time"
      
      f.puts "\n### Optimization Areas"
      f.puts "Look for methods with:"
      f.puts "- High self time (CPU bottlenecks)"
      f.puts "- High call count (potential optimization targets)"
      f.puts "- Large memory allocations (memory optimization opportunities)"
      f.puts "- Deep call stacks (potential for simplification)"
    end
    
    puts "✅ Report generated: #{report_file}"
  end

  desc "Clean up old performance profiles"
  task clean: :environment do
    profile_dir = Rails.root.join('tmp', 'performance_profiles')
    if Dir.exist?(profile_dir)
      FileUtils.rm_rf(profile_dir)
      puts "🧹 Cleaned up performance profiles"
    else
      puts "📁 No profiles to clean"
    end
  end
end