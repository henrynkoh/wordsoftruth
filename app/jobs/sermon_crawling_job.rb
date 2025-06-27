class SermonCrawlingJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Starting sermon crawling job at #{Time.current}"
    SermonCrawlerService.crawl_all
    Rails.logger.info "Completed sermon crawling job at #{Time.current}"
  rescue StandardError => e
    Rails.logger.error "Error in sermon crawling job: #{e.message}"
    raise e
  end
end 