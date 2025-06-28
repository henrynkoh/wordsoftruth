require "test_helper"

class SermonCrawlingJobTest < ActiveJob::TestCase
  def setup
    @valid_url = "https://example-church.com/sermons/faith-hope"
    @job = SermonCrawlingJob.new
  end

  # Basic Job Execution Tests
  test "should enqueue job with URL" do
    assert_enqueued_with(job: SermonCrawlingJob, args: [@valid_url]) do
      SermonCrawlingJob.perform_later(@valid_url)
    end
  end

  test "should execute job with valid URL" do
    # Mock the service call
    crawler_service = mock('crawler_service')
    result = mock('result')
    result.stubs(:success?).returns(true)
    result.stubs(:sermon).returns(sermons(:one))
    
    SermonCrawlerService.expects(:new).returns(crawler_service)
    crawler_service.expects(:crawl).with(@valid_url).returns(result)
    
    perform_enqueued_jobs do
      SermonCrawlingJob.perform_later(@valid_url)
    end
  end

  test "should handle successful crawling" do
    sermon = sermons(:one)
    
    # Mock successful service result
    service_result = mock('service_result')
    service_result.stubs(:success?).returns(true)
    service_result.stubs(:sermon).returns(sermon)
    
    crawler_service = mock('crawler_service')
    crawler_service.expects(:crawl).returns(service_result)
    SermonCrawlerService.expects(:new).returns(crawler_service)
    
    # Expect video generation job to be enqueued
    assert_enqueued_with(job: VideoProcessingJob, args: [sermon.id]) do
      @job.perform(@valid_url)
    end
  end

  test "should handle crawling failure" do
    # Mock failed service result
    service_result = mock('service_result')
    service_result.stubs(:success?).returns(false)
    service_result.stubs(:error).returns("Network timeout")
    
    crawler_service = mock('crawler_service')
    crawler_service.expects(:crawl).returns(service_result)
    SermonCrawlerService.expects(:new).returns(crawler_service)
    
    # Should not enqueue video processing job
    assert_no_enqueued_jobs(only: VideoProcessingJob) do
      @job.perform(@valid_url)
    end
  end

  # Error Handling Tests
  test "should handle service exceptions gracefully" do
    # Mock service raising exception
    crawler_service = mock('crawler_service')
    crawler_service.expects(:crawl).raises(StandardError.new("Service error"))
    SermonCrawlerService.expects(:new).returns(crawler_service)
    
    # Job should not fail catastrophically
    assert_nothing_raised do
      @job.perform(@valid_url)
    end
  end

  # Input Validation Tests
  test "should validate URL parameter" do
    invalid_urls = [
      nil,
      "",
      "not-a-url",
      "javascript:alert('xss')",
      "file:///etc/passwd"
    ]
    
    invalid_urls.each do |url|
      assert_raises ArgumentError do
        @job.perform(url)
      end
    end
  end

  test "should accept valid URLs" do
    valid_urls = [
      "https://example.com/sermon",
      "http://church.org/message",
      "https://subdomain.church.com/sermons/123"
    ]
    
    valid_urls.each do |url|
      # Mock successful service call
      result = mock('result')
      result.stubs(:success?).returns(true)
      result.stubs(:sermon).returns(sermons(:one))
      
      crawler_service = mock('crawler_service')
      crawler_service.expects(:crawl).returns(result)
      SermonCrawlerService.expects(:new).returns(crawler_service)
      
      assert_nothing_raised do
        @job.perform(url)
      end
    end
  end
end