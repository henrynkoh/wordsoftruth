# frozen_string_literal: true

require "nokogiri"
require "net/http"
require "uri"

class SermonCrawlerService
  CHURCH_CONFIGS = {
    "example_church" => {
      url: "https://example.com/sermons",
      selectors: {
        title: ".sermon-title",
        scripture: ".sermon-scripture",
        pastor: ".pastor-name",
        date: ".sermon-date",
      },
    },
  }.freeze

  # Network timeout constants
  CONNECTION_TIMEOUT = 10
  READ_TIMEOUT = 30

  class << self
    def crawl_all
      CHURCH_CONFIGS.each do |church_name, config|
        new(church_name, config).crawl
      end
    end
  end

  def initialize(church_name, config)
    @church_name = church_name
    @config = config
  end

  def crawl
    Rails.logger.info "Starting crawl for #{@church_name}"

    doc = fetch_page(@config[:url])
    return unless doc

    sermons = parse_sermons(doc)
    save_sermons(sermons)

    Rails.logger.info "Completed crawl for #{@church_name}: #{sermons.size} sermons processed"
  rescue StandardError => e
    Rails.logger.error "Error crawling #{@church_name}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  private

  def fetch_page(url)
    validate_url!(url)

    uri = URI.parse(url)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = CONNECTION_TIMEOUT
    http.read_timeout = READ_TIMEOUT

    request = Net::HTTP::Get.new(uri.request_uri)
    request["User-Agent"] = "SermonCrawler/1.0"

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error "HTTP error for #{url}: #{response.code} #{response.message}"
      return nil
    end

    Nokogiri::HTML(response.body)
  rescue StandardError => e
    Rails.logger.error "Failed to fetch #{url}: #{e.message}"
    nil
  end

  def validate_url!(url)
    uri = URI.parse(url)

    unless %w[http https].include?(uri.scheme)
      raise ArgumentError, "Invalid URL scheme: #{uri.scheme}"
    end

    unless uri.host
      raise ArgumentError, "URL must have a host"
    end

    # Prevent SSRF attacks by blocking internal networks
    if uri.host.match?(/\A(127\.|10\.|172\.(1[6-9]|2\d|3[01])\.|192\.168\.)/)
      raise ArgumentError, "Access to private networks is not allowed"
    end
  end

  def parse_sermons(doc)
    sermon_elements = doc.css(".sermon-item")

    return [] if sermon_elements.empty?

    sermon_elements.filter_map do |sermon_element|
      build_sermon_data(sermon_element)
    end.compact
  end

  def build_sermon_data(sermon_element)
    title = extract_text(sermon_element, @config[:selectors][:title])
    source_url = extract_url(sermon_element)

    # Skip if we don't have the minimum required data
    return nil if title.blank? || source_url.blank?

    {
      title: title,
      scripture: extract_text(sermon_element, @config[:selectors][:scripture]),
      pastor: extract_text(sermon_element, @config[:selectors][:pastor]),
      sermon_date: parse_date(extract_text(sermon_element, @config[:selectors][:date])),
      church: @church_name,
      source_url: source_url,
    }
  end

  def extract_text(element, selector)
    return "" if selector.blank?

    text = element.css(selector).text.strip
    text.present? ? text : ""
  end

  def extract_url(element)
    link = element.css("a").first
    return nil unless link

    href = link["href"]
    return nil if href.blank?

    # Convert relative URLs to absolute URLs
    if href.start_with?("/")
      uri = URI.parse(@config[:url])
      "#{uri.scheme}://#{uri.host}#{href}"
    else
      href
    end
  end

  def parse_date(date_string)
    return nil if date_string.blank?

    DateTime.parse(date_string)
  rescue ArgumentError => e
    Rails.logger.warn "Failed to parse date '#{date_string}': #{e.message}"
    nil
  end

  def save_sermons(sermons)
    return [] if sermons.empty?

    Rails.logger.info "Saving #{sermons.size} sermons for #{@church_name}"

    saved_count = 0
    failed_count = 0
    new_sermons = []

    # Process in batches to manage memory and improve performance
    sermons.each_slice(50) do |sermon_batch|
      batch_result = save_sermon_batch(sermon_batch)
      saved_count += batch_result[:saved]
      failed_count += batch_result[:failed]
      new_sermons.concat(batch_result[:new_sermons])
      
      # Garbage collect after each batch to manage memory
      GC.start if sermons.size > 100
    end

    Rails.logger.info "Sermon save results: #{saved_count} saved, #{failed_count} failed"
    
    # Clear relevant caches since new sermons were added
    clear_sermon_caches if saved_count > 0
    
    new_sermons
  end

  def save_sermon_batch(sermon_batch)
    saved_count = 0
    failed_count = 0
    new_sermons = []
    
    # Use transaction for batch processing
    Sermon.transaction do
      sermon_batch.each do |sermon_data|
        result = save_single_sermon_optimized(sermon_data)
        if result[:success]
          saved_count += 1
          new_sermons << result[:sermon] if result[:is_new]
        else
          failed_count += 1
        end
      end
    end
    
    { saved: saved_count, failed: failed_count, new_sermons: new_sermons }
  rescue => e
    Rails.logger.error "Batch save failed: #{e.message}"
    { saved: 0, failed: sermon_batch.size, new_sermons: [] }
  end

  def save_single_sermon_optimized(sermon_data)
    # Use find_or_initialize_by for better performance
    sermon = Sermon.find_or_initialize_by(source_url: sermon_data[:source_url]) do |s|
      s.assign_attributes(sermon_data.except(:source_url))
    end
    
    is_new = sermon.new_record?
    
    if sermon.save
      { success: true, sermon: sermon, is_new: is_new }
    else
      Rails.logger.warn "Failed to save sermon: #{sermon.errors.full_messages.join(', ')}"
      { success: false, error: sermon.errors.full_messages }
    end
  rescue => e
    Rails.logger.error "Error saving sermon: #{e.message}"
    { success: false, error: e.message }
  end

  def clear_sermon_caches
    Rails.cache.delete("sermon_counts")
    Rails.cache.delete_matched("recent_sermons_*")
    Rails.cache.delete("dashboard_stats")
  end

  def save_single_sermon(sermon_data)
    sermon = Sermon.find_or_initialize_by(source_url: sermon_data[:source_url])

    # Only update if this is a new record or the data has changed
    if sermon.new_record? || sermon_attributes_changed?(sermon, sermon_data)
      sermon.assign_attributes(sermon_data)

      if sermon.save
        Rails.logger.debug "Saved sermon: #{sermon.title}"
        true
      else
        Rails.logger.error "Failed to save sermon '#{sermon_data[:title]}': #{sermon.errors.full_messages.join(', ')}"
        false
      end
    else
      Rails.logger.debug "Skipping unchanged sermon: #{sermon.title}"
      true
    end
  end

  def sermon_attributes_changed?(sermon, new_data)
    %i[title scripture pastor sermon_date church].any? do |attr|
      sermon.send(attr) != new_data[attr]
    end
  end
end
