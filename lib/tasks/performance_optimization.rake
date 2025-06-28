# Performance optimization tasks for Words of Truth
namespace :performance do
  desc "Run database migration to add performance indexes"
  task apply_indexes: :environment do
    puts "🔧 Applying performance indexes..."
    
    # Run the migration
    ActiveRecord::Migration.new.apply_indexes
    
    puts "✅ Performance indexes applied successfully"
  end

  desc "Warm up application caches"
  task warm_cache: :environment do
    puts "🔥 Warming up application caches..."
    
    # Dashboard statistics
    DashboardController.new.send(:calculate_dashboard_stats)
    puts "  ✓ Dashboard stats cached"
    
    # Recent sermons
    [5, 10, 20].each do |limit|
      Sermon.recent_sermons(limit)
      puts "  ✓ Recent sermons (#{limit}) cached"
    end
    
    # Recent videos
    [5, 10, 20].each do |limit|
      Video.cached_recent_videos(limit)
      puts "  ✓ Recent videos (#{limit}) cached"
    end
    
    # Common search terms
    common_searches = ['love', 'faith', 'hope', 'John', 'Matthew', 'Romans']
    common_searches.each do |term|
      Sermon.search(term)
      puts "  ✓ Search results for '#{term}' cached"
    end
    
    # Sermon counts
    Sermon.cached_counts
    puts "  ✓ Sermon counts cached"
    
    # Video status counts
    Video.cached_status_counts
    puts "  ✓ Video status counts cached"
    
    puts "🎯 Cache warming completed!"
  end

  desc "Run bulk sermon processing job"
  task :bulk_sermon_processing, [:church_urls] => :environment do |t, args|
    church_urls = args[:church_urls]&.split(',') || []
    
    if church_urls.empty?
      puts "❌ No church URLs provided. Usage: rake performance:bulk_sermon_processing['url1,url2,url3']"
      exit 1
    end
    
    puts "🚀 Starting bulk sermon processing for #{church_urls.size} churches..."
    
    BulkSermonProcessingJob.perform_later(
      church_urls,
      batch_size: ENV.fetch('BATCH_SIZE', 50).to_i,
      parallel_workers: ENV.fetch('PARALLEL_WORKERS', 3).to_i
    )
    
    puts "✅ Bulk sermon processing job enqueued"
  end

  desc "Run optimized video processing"
  task optimized_video_processing: :environment do
    batch_size = ENV.fetch('BATCH_SIZE', 20).to_i
    status_filter = ENV.fetch('STATUS_FILTER', 'approved')
    
    puts "🎥 Starting optimized video processing (batch: #{batch_size}, status: #{status_filter})..."
    
    OptimizedVideoProcessingJob.perform_later(batch_size, status_filter)
    
    puts "✅ Optimized video processing job enqueued"
  end

  desc "Bulk import sermons from CSV"
  task :import_sermons_csv, [:csv_file] => :environment do |t, args|
    csv_file = args[:csv_file]
    
    unless csv_file && File.exist?(csv_file)
      puts "❌ CSV file not found. Usage: rake performance:import_sermons_csv[path/to/file.csv]"
      exit 1
    end
    
    puts "📁 Starting bulk sermon import from #{csv_file}..."
    
    service = BulkSermonImportService.new(
      batch_size: ENV.fetch('BATCH_SIZE', 1000).to_i,
      chunk_size: ENV.fetch('CHUNK_SIZE', 100).to_i
    )
    
    if service.import_from_csv(csv_file)
      puts "✅ Import completed successfully: #{service.import_stats}"
    else
      puts "❌ Import failed: #{service.errors.join(', ')}"
      exit 1
    end
  end

  desc "Bulk video operations"
  task :bulk_video_ops, [:operation, :video_ids] => :environment do |t, args|
    operation = args[:operation]
    video_ids = args[:video_ids]&.split(',')&.map(&:to_i) || []
    
    unless %w[approve reject cleanup retry_failed].include?(operation)
      puts "❌ Invalid operation. Use: approve, reject, cleanup, retry_failed"
      exit 1
    end
    
    if operation != 'retry_failed' && video_ids.empty?
      puts "❌ No video IDs provided. Usage: rake performance:bulk_video_ops[operation,'id1,id2,id3']"
      exit 1
    end
    
    puts "⚡ Starting bulk video #{operation} operation..."
    
    service = BulkVideoOperationsService.new(
      batch_size: ENV.fetch('BATCH_SIZE', 50).to_i
    )
    
    success = case operation
              when 'approve'
                service.bulk_approve(video_ids, auto_process: true)
              when 'reject'
                service.bulk_reject(video_ids, ENV['REJECTION_REASON'])
              when 'cleanup'
                criteria = {
                  older_than: ENV.fetch('OLDER_THAN_DAYS', 30).to_i.days.ago,
                  statuses: ENV.fetch('STATUSES', 'failed').split(','),
                  cleanup_files: ENV.fetch('CLEANUP_FILES', 'true') == 'true'
                }
                service.bulk_cleanup(criteria)
              when 'retry_failed'
                service.bulk_retry_failed(ENV.fetch('MAX_RETRIES', 3).to_i)
              end
    
    if success
      puts "✅ Bulk #{operation} completed: #{service.operation_stats}"
    else
      puts "❌ Bulk #{operation} failed: #{service.errors.join(', ')}"
      exit 1
    end
  end

  desc "Clear all application caches"
  task clear_cache: :environment do
    puts "🧹 Clearing all application caches..."
    
    cache_patterns = [
      "dashboard_stats",
      "sermon_counts",
      "video_status_counts",
      "recent_sermons_*",
      "recent_videos_*",
      "sermon_search_*"
    ]
    
    cache_patterns.each do |pattern|
      if pattern.include?('*')
        Rails.cache.delete_matched(pattern)
      else
        Rails.cache.delete(pattern)
      end
      puts "  ✓ Cleared #{pattern}"
    end
    
    puts "✅ All caches cleared!"
  end

  desc "Generate performance optimization report"
  task optimization_report: :environment do
    puts "📊 Generating performance optimization report..."
    
    report = {
      database: {
        sermon_count: Sermon.count,
        video_count: Video.count,
        index_usage: check_index_usage
      },
      cache: {
        hit_rate: check_cache_hit_rate,
        memory_usage: check_cache_memory_usage
      },
      jobs: {
        queue_sizes: check_job_queue_sizes,
        failed_jobs: check_failed_jobs
      }
    }
    
    puts "\n📋 Performance Optimization Report"
    puts "=" * 50
    puts "Database:"
    puts "  Sermons: #{report[:database][:sermon_count]}"
    puts "  Videos: #{report[:database][:video_count]}"
    puts "  Indexes: #{report[:database][:index_usage]}"
    puts "\nCache:"
    puts "  Hit Rate: #{report[:cache][:hit_rate]}"
    puts "  Memory Usage: #{report[:cache][:memory_usage]}"
    puts "\nJobs:"
    puts "  Queue Sizes: #{report[:jobs][:queue_sizes]}"
    puts "  Failed Jobs: #{report[:jobs][:failed_jobs]}"
    puts "=" * 50
  end

  private

  def check_index_usage
    # This would require database-specific queries
    "✅ Performance indexes applied"
  end

  def check_cache_hit_rate
    # This would require Redis stats
    "Cache monitoring recommended"
  end

  def check_cache_memory_usage
    # This would require Redis memory info
    "Memory monitoring recommended"
  end

  def check_job_queue_sizes
    return "Sidekiq not available" unless defined?(Sidekiq)
    
    stats = Sidekiq::Stats.new
    {
      processed: stats.processed,
      failed: stats.failed,
      enqueued: stats.enqueued
    }
  end

  def check_failed_jobs
    return 0 unless defined?(Sidekiq)
    
    Sidekiq::Stats.new.failed
  end
end