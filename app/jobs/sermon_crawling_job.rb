# frozen_string_literal: true

class SermonCrawlingJob < ApplicationJob
  queue_as :default

  # Retry failed jobs with exponential backoff
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  # Discard jobs that fail due to configuration issues
  discard_on ArgumentError, SermonCrawlerService::ConfigurationError if defined?(SermonCrawlerService::ConfigurationError)

  def perform(church_names = nil)
    start_time = Time.current
    Rails.logger.info "Starting sermon crawling job at #{start_time}"

    churches_to_crawl = determine_churches_to_crawl(church_names)

    if churches_to_crawl.empty?
      Rails.logger.warn "No churches configured for crawling"
      return
    end

    results = crawl_churches(churches_to_crawl)
    log_crawling_results(results, start_time)

  rescue StandardError => e
    Rails.logger.error "Error in sermon crawling job: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise e
  end

  private

  def determine_churches_to_crawl(church_names)
    if church_names.present?
      # Crawl only specified churches
      Array(church_names).map(&:to_s)
    else
      # Crawl all configured churches
      SermonCrawlerService::CHURCH_CONFIGS.keys
    end
  end

  def crawl_churches(church_names)
    results = {
      success: [],
      failed: [],
      total_sermons: 0,
    }

    church_names.each do |church_name|
      result = crawl_single_church(church_name)

      if result[:success]
        results[:success] << church_name
        results[:total_sermons] += result[:sermons_count]
      else
        results[:failed] << { church: church_name, error: result[:error] }
      end
    end

    results
  end

  def crawl_single_church(church_name)
    config = SermonCrawlerService::CHURCH_CONFIGS[church_name]

    unless config
      return { success: false, error: "No configuration found for #{church_name}" }
    end

    Rails.logger.info "Crawling #{church_name}"

    crawler = SermonCrawlerService.new(church_name, config)
    sermons_count = crawler.crawl

    { success: true, sermons_count: sermons_count || 0 }
  rescue StandardError => e
    Rails.logger.error "Failed to crawl #{church_name}: #{e.message}"
    { success: false, error: e.message }
  end

  def log_crawling_results(results, start_time)
    duration = Time.current - start_time

    Rails.logger.info "Completed sermon crawling job in #{duration.round(2)} seconds"
    Rails.logger.info "Success: #{results[:success].size} churches"
    Rails.logger.info "Failed: #{results[:failed].size} churches"
    Rails.logger.info "Total sermons processed: #{results[:total_sermons]}"

    if results[:failed].any?
      Rails.logger.warn "Failed churches: #{results[:failed].map { |f| f[:church] }.join(', ')}"
    end
  end
end
