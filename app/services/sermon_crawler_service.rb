require 'nokogiri'
require 'open-uri'

class SermonCrawlerService
  CHURCH_CONFIGS = {
    'example_church' => {
      url: 'https://example.com/sermons',
      selectors: {
        title: '.sermon-title',
        scripture: '.sermon-scripture',
        pastor: '.pastor-name',
        date: '.sermon-date'
      }
    }
  }

  def self.crawl_all
    CHURCH_CONFIGS.each do |church_name, config|
      new(church_name, config).crawl
    end
  end

  def initialize(church_name, config)
    @church_name = church_name
    @config = config
  end

  def crawl
    doc = fetch_page(@config[:url])
    sermons = parse_sermons(doc)
    save_sermons(sermons)
  rescue StandardError => e
    Rails.logger.error "Error crawling #{@church_name}: #{e.message}"
  end

  private

  def fetch_page(url)
    Nokogiri::HTML(URI.open(url))
  end

  def parse_sermons(doc)
    doc.css('.sermon-item').map do |sermon_element|
      {
        title: extract_text(sermon_element, @config[:selectors][:title]),
        scripture: extract_text(sermon_element, @config[:selectors][:scripture]),
        pastor: extract_text(sermon_element, @config[:selectors][:pastor]),
        sermon_date: parse_date(extract_text(sermon_element, @config[:selectors][:date])),
        church: @church_name,
        source_url: extract_url(sermon_element)
      }
    end
  end

  def extract_text(element, selector)
    element.css(selector).text.strip
  end

  def extract_url(element)
    element.css('a').first&.[]('href')
  end

  def parse_date(date_string)
    DateTime.parse(date_string)
  rescue ArgumentError
    nil
  end

  def save_sermons(sermons)
    sermons.each do |sermon_data|
      sermon = Sermon.find_or_initialize_by(source_url: sermon_data[:source_url])
      sermon.assign_attributes(sermon_data)
      
      if sermon.save
        Rails.logger.info "Saved sermon: #{sermon.title}"
      else
        Rails.logger.error "Failed to save sermon: #{sermon.errors.full_messages.join(', ')}"
      end
    end
  end
end 