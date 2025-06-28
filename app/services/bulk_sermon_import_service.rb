# Optimized bulk import service for large sermon datasets
class BulkSermonImportService
  include ActiveModel::Validations
  
  attr_reader :import_stats, :errors
  
  def initialize(options = {})
    @batch_size = options[:batch_size] || 1000
    @chunk_size = options[:chunk_size] || 100
    @parallel_workers = options[:parallel_workers] || 4
    @import_stats = { created: 0, updated: 0, failed: 0, total: 0 }
    @errors = []
  end

  # Bulk import from CSV file
  def import_from_csv(file_path)
    validate_csv_file(file_path)
    return false unless errors.empty?

    Rails.logger.info "Starting bulk CSV import from #{file_path}"
    start_time = Time.current

    CSV.foreach(file_path, headers: true, chunk_size: @chunk_size) do |chunk|
      process_csv_chunk(chunk)
    end

    duration = Time.current - start_time
    Rails.logger.info "CSV import completed in #{duration.round(2)}s: #{@import_stats}"
    
    clear_all_caches
    true
  rescue => e
    Rails.logger.error "CSV import failed: #{e.message}"
    @errors << "Import failed: #{e.message}"
    false
  end

  # Bulk import from array of sermon hashes
  def import_from_array(sermons_data)
    return false if sermons_data.empty?

    Rails.logger.info "Starting bulk array import for #{sermons_data.size} sermons"
    @import_stats[:total] = sermons_data.size
    start_time = Time.current

    # Process in chunks for memory efficiency
    sermons_data.each_slice(@chunk_size) do |chunk|
      process_sermon_chunk(chunk)
    end

    duration = Time.current - start_time
    Rails.logger.info "Array import completed in #{duration.round(2)}s: #{@import_stats}"
    
    clear_all_caches
    true
  rescue => e
    Rails.logger.error "Array import failed: #{e.message}"
    @errors << "Import failed: #{e.message}"
    false
  end

  # Bulk upsert using Rails 6+ upsert_all
  def bulk_upsert(sermons_data)
    return false if sermons_data.empty?

    Rails.logger.info "Starting bulk upsert for #{sermons_data.size} sermons"
    start_time = Time.current

    # Prepare data for upsert
    upsert_data = prepare_upsert_data(sermons_data)
    
    # Perform bulk upsert in batches
    upsert_data.each_slice(@batch_size) do |batch|
      perform_bulk_upsert_batch(batch)
    end

    duration = Time.current - start_time
    Rails.logger.info "Bulk upsert completed in #{duration.round(2)}s: #{@import_stats}"
    
    clear_all_caches
    true
  rescue => e
    Rails.logger.error "Bulk upsert failed: #{e.message}"
    @errors << "Bulk upsert failed: #{e.message}"
    false
  end

  private

  def validate_csv_file(file_path)
    unless File.exist?(file_path)
      @errors << "CSV file not found: #{file_path}"
      return
    end

    unless File.readable?(file_path)
      @errors << "CSV file not readable: #{file_path}"
      return
    end

    # Validate CSV headers
    begin
      headers = CSV.read(file_path, headers: true).headers
      required_headers = %w[title source_url church]
      missing_headers = required_headers - headers
      
      if missing_headers.any?
        @errors << "Missing required CSV headers: #{missing_headers.join(', ')}"
      end
    rescue => e
      @errors << "Invalid CSV file: #{e.message}"
    end
  end

  def process_csv_chunk(chunk)
    sermon_data = chunk.map do |row|
      {
        title: row['title']&.strip,
        source_url: row['source_url']&.strip,
        church: row['church']&.strip,
        pastor: row['pastor']&.strip,
        scripture: row['scripture']&.strip,
        interpretation: row['interpretation']&.strip,
        denomination: row['denomination']&.strip,
        audience_count: row['audience_count']&.to_i
      }.compact_blank
    end

    process_sermon_chunk(sermon_data)
  end

  def process_sermon_chunk(sermon_data)
    # Filter out invalid records
    valid_data = sermon_data.select { |data| valid_sermon_data?(data) }
    
    if valid_data.size != sermon_data.size
      @import_stats[:failed] += (sermon_data.size - valid_data.size)
    end

    return if valid_data.empty?

    # Use transaction for chunk
    Sermon.transaction do
      valid_data.each do |data|
        process_single_sermon(data)
      end
    end
  rescue => e
    Rails.logger.error "Chunk processing failed: #{e.message}"
    @import_stats[:failed] += sermon_data.size
  end

  def process_single_sermon(sermon_data)
    sermon = Sermon.find_or_initialize_by(source_url: sermon_data[:source_url])
    
    if sermon.persisted?
      # Update existing sermon
      sermon.assign_attributes(sermon_data.except(:source_url))
      if sermon.changed? && sermon.save
        @import_stats[:updated] += 1
      end
    else
      # Create new sermon
      sermon.assign_attributes(sermon_data)
      if sermon.save
        @import_stats[:created] += 1
      else
        @import_stats[:failed] += 1
        Rails.logger.warn "Failed to save sermon: #{sermon.errors.full_messages.join(', ')}"
      end
    end
  rescue => e
    @import_stats[:failed] += 1
    Rails.logger.error "Error processing sermon: #{e.message}"
  end

  def prepare_upsert_data(sermons_data)
    timestamp = Time.current
    
    sermons_data.map do |data|
      data.merge(
        created_at: timestamp,
        updated_at: timestamp
      ).stringify_keys
    end
  end

  def perform_bulk_upsert_batch(batch)
    result = Sermon.upsert_all(
      batch,
      unique_by: :source_url,
      update_only: [:title, :pastor, :scripture, :interpretation, :church, :denomination, :audience_count, :updated_at]
    )
    
    @import_stats[:created] += result
  rescue => e
    @import_stats[:failed] += batch.size
    Rails.logger.error "Bulk upsert batch failed: #{e.message}"
  end

  def valid_sermon_data?(data)
    return false if data[:title].blank?
    return false if data[:source_url].blank?
    return false if data[:church].blank?
    
    # Validate URL format
    begin
      URI.parse(data[:source_url])
    rescue URI::InvalidURIError
      return false
    end
    
    true
  end

  def clear_all_caches
    Rails.cache.delete("sermon_counts")
    Rails.cache.delete("dashboard_stats")
    Rails.cache.delete_matched("recent_sermons_*")
    Rails.cache.delete_matched("sermon_search_*")
  end
end