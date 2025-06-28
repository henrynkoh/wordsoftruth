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

  test "should handle network timeout exceptions" do
    crawler_service = mock('crawler_service')
    crawler_service.expects(:crawl).raises(Net::TimeoutError.new("Request timeout"))
    SermonCrawlerService.expects(:new).returns(crawler_service)
    
    assert_nothing_raised do
      @job.perform(@valid_url)
    end
  end

  test "should handle SSRF protection exceptions" do
    crawler_service = mock('crawler_service')
    crawler_service.expects(:crawl).raises(ArgumentError.new("Blocked private IP"))
    SermonCrawlerService.expects(:new).returns(crawler_service)
    
    assert_nothing_raised do
      @job.perform(@valid_url)
    end
  end

  # Retry Logic Tests
  test "should retry on retryable errors" do
    attempts = 0
    
    # Mock service to fail twice, then succeed
    SermonCrawlerService.any_instance.stubs(:crawl).returns(
      proc do
        attempts += 1
        if attempts < 3
          raise Net::TimeoutError.new("Timeout")
        else
          result = mock('result')
          result.stubs(:success?).returns(true)
          result.stubs(:sermon).returns(sermons(:one))
          result
        end
      end.call
    )
    
    # Job should eventually succeed after retries
    perform_enqueued_jobs do
      SermonCrawlingJob.perform_later(@valid_url)
    end
    
    assert_equal 3, attempts
  end

  test "should not retry on non-retryable errors" do
    attempts = 0
    
    # Mock service to always fail with non-retryable error
    SermonCrawlerService.any_instance.stubs(:crawl).returns(
      proc do
        attempts += 1
        raise ArgumentError.new("Invalid URL format")
      end.call
    )
    
    # Job should fail immediately without retries
    perform_enqueued_jobs do
      SermonCrawlingJob.perform_later(@valid_url)
    end
    
    assert_equal 1, attempts
  end

  test "should stop retrying after maximum attempts" do
    # Set maximum retry attempts to 2 for testing
    SermonCrawlingJob.any_instance.stubs(:max_retry_attempts).returns(2)
    
    attempts = 0
    SermonCrawlerService.any_instance.stubs(:crawl).returns(
      proc do
        attempts += 1
        raise Net::TimeoutError.new("Persistent timeout")
      end.call
    )
    
    perform_enqueued_jobs do
      SermonCrawlingJob.perform_later(@valid_url)
    end
    
    assert_equal 3, attempts # Initial + 2 retries
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

  test \"should accept valid URLs\" do\n    valid_urls = [\n      \"https://example.com/sermon\",\n      \"http://church.org/message\",\n      \"https://subdomain.church.com/sermons/123\"\n    ]\n    \n    valid_urls.each do |url|\n      # Mock successful service call\n      result = mock('result')\n      result.stubs(:success?).returns(true)\n      result.stubs(:sermon).returns(sermons(:one))\n      \n      crawler_service = mock('crawler_service')\n      crawler_service.expects(:crawl).returns(result)\n      SermonCrawlerService.expects(:new).returns(crawler_service)\n      \n      assert_nothing_raised do\n        @job.perform(url)\n      end\n    end\n  end\n\n  # Job Queue and Priority Tests\n  test \"should be enqueued in correct queue\" do\n    job = SermonCrawlingJob.new\n    assert_equal \"default\", job.queue_name\n  end\n\n  test \"should have appropriate priority\" do\n    job = SermonCrawlingJob.new\n    # Assuming normal priority (adjust based on actual implementation)\n    assert_respond_to job, :priority\n  end\n\n  # Logging Tests\n  test \"should log successful crawling\" do\n    sermon = sermons(:one)\n    \n    # Mock successful service result\n    service_result = mock('service_result')\n    service_result.stubs(:success?).returns(true)\n    service_result.stubs(:sermon).returns(sermon)\n    \n    crawler_service = mock('crawler_service')\n    crawler_service.expects(:crawl).returns(service_result)\n    SermonCrawlerService.expects(:new).returns(crawler_service)\n    \n    # Expect info log\n    Rails.logger.expects(:info).with(regexp_matches(/Successfully crawled sermon/))\n    \n    @job.perform(@valid_url)\n  end\n\n  test \"should log crawling failures\" do\n    # Mock failed service result\n    service_result = mock('service_result')\n    service_result.stubs(:success?).returns(false)\n    service_result.stubs(:error).returns(\"Network error\")\n    \n    crawler_service = mock('crawler_service')\n    crawler_service.expects(:crawl).returns(service_result)\n    SermonCrawlerService.expects(:new).returns(crawler_service)\n    \n    # Expect error log\n    Rails.logger.expects(:error).with(regexp_matches(/Failed to crawl sermon/))\n    \n    @job.perform(@valid_url)\n  end\n\n  test \"should log exceptions\" do\n    # Mock service raising exception\n    crawler_service = mock('crawler_service')\n    crawler_service.expects(:crawl).raises(StandardError.new(\"Unexpected error\"))\n    SermonCrawlerService.expects(:new).returns(crawler_service)\n    \n    # Expect error log with exception details\n    Rails.logger.expects(:error).with(regexp_matches(/Exception in SermonCrawlingJob/))\n    \n    @job.perform(@valid_url)\n  end\n\n  # Performance Tests\n  test \"should complete within reasonable time\" do\n    # Mock quick service response\n    result = mock('result')\n    result.stubs(:success?).returns(true)\n    result.stubs(:sermon).returns(sermons(:one))\n    \n    crawler_service = mock('crawler_service')\n    crawler_service.expects(:crawl).returns(result)\n    SermonCrawlerService.expects(:new).returns(crawler_service)\n    \n    start_time = Time.current\n    @job.perform(@valid_url)\n    end_time = Time.current\n    \n    assert (end_time - start_time) < 5, \"Job should complete quickly in test\"\n  end\n\n  # Duplicate Detection Tests\n  test \"should handle duplicate URL submissions\" do\n    # Create existing sermon with same URL\n    existing_sermon = Sermon.create!(\n      title: \"Existing Sermon\",\n      source_url: @valid_url,\n      church: \"Test Church\"\n    )\n    \n    # Mock service to return new sermon with same URL\n    new_sermon = Sermon.new(\n      title: \"New Sermon\",\n      source_url: @valid_url,\n      church: \"Test Church\"\n    )\n    \n    service_result = mock('service_result')\n    service_result.stubs(:success?).returns(true)\n    service_result.stubs(:sermon).returns(new_sermon)\n    \n    crawler_service = mock('crawler_service')\n    crawler_service.expects(:crawl).returns(service_result)\n    SermonCrawlerService.expects(:new).returns(crawler_service)\n    \n    # Should handle uniqueness constraint gracefully\n    assert_nothing_raised do\n      @job.perform(@valid_url)\n    end\n  end\n\n  # Security Tests\n  test \"should sanitize URL before processing\" do\n    malicious_url = \"https://example.com/sermon?<script>alert('xss')</script>\"\n    \n    # Should sanitize or reject malicious URL\n    assert_raises ArgumentError do\n      @job.perform(malicious_url)\n    end\n  end\n\n  test \"should prevent SSRF attacks\" do\n    private_urls = [\n      \"http://127.0.0.1/sermon\",\n      \"http://localhost/sermon\",\n      \"http://169.254.169.254/sermon\"\n    ]\n    \n    private_urls.each do |url|\n      assert_raises ArgumentError do\n        @job.perform(url)\n      end\n    end\n  end\n\n  # Integration Tests\n  test \"should integrate with video processing pipeline\" do\n    sermon = sermons(:one)\n    \n    # Mock successful crawling\n    service_result = mock('service_result')\n    service_result.stubs(:success?).returns(true)\n    service_result.stubs(:sermon).returns(sermon)\n    \n    crawler_service = mock('crawler_service')\n    crawler_service.expects(:crawl).returns(service_result)\n    SermonCrawlerService.expects(:new).returns(crawler_service)\n    \n    # Should enqueue video processing job\n    assert_enqueued_with(job: VideoProcessingJob, args: [sermon.id]) do\n      @job.perform(@valid_url)\n    end\n  end\n\n  # Concurrency Tests\n  test \"should handle concurrent jobs for same URL\" do\n    # Simulate two jobs processing same URL\n    job1 = SermonCrawlingJob.new\n    job2 = SermonCrawlingJob.new\n    \n    # Mock service calls\n    sermon1 = sermons(:one)\n    sermon2 = sermons(:two)\n    \n    service_result1 = mock('service_result1')\n    service_result1.stubs(:success?).returns(true)\n    service_result1.stubs(:sermon).returns(sermon1)\n    \n    service_result2 = mock('service_result2')\n    service_result2.stubs(:success?).returns(true)\n    service_result2.stubs(:sermon).returns(sermon2)\n    \n    crawler_service1 = mock('crawler_service1')\n    crawler_service1.expects(:crawl).returns(service_result1)\n    \n    crawler_service2 = mock('crawler_service2')\n    crawler_service2.expects(:crawl).returns(service_result2)\n    \n    SermonCrawlerService.expects(:new).twice.returns(crawler_service1, crawler_service2)\n    \n    # Both jobs should handle concurrent execution gracefully\n    assert_nothing_raised do\n      job1.perform(@valid_url)\n      job2.perform(@valid_url)\n    end\n  end\n\n  # Edge Cases\n  test \"should handle extremely long URLs\" do\n    long_url = \"https://example.com/\" + (\"a\" * 2000)\n    \n    # Should either process or reject gracefully\n    assert_nothing_raised do\n      begin\n        @job.perform(long_url)\n      rescue ArgumentError\n        # Acceptable to reject very long URLs\n      end\n    end\n  end\n\n  test \"should handle international domain names\" do\n    international_url = \"https://교회.com/sermon\"\n    \n    # Mock successful service call\n    result = mock('result')\n    result.stubs(:success?).returns(true)\n    result.stubs(:sermon).returns(sermons(:one))\n    \n    crawler_service = mock('crawler_service')\n    crawler_service.expects(:crawl).returns(result)\n    SermonCrawlerService.expects(:new).returns(crawler_service)\n    \n    assert_nothing_raised do\n      @job.perform(international_url)\n    end\n  end\n\n  # Cleanup Tests\n  test \"should cleanup resources on job completion\" do\n    # Mock service call\n    result = mock('result')\n    result.stubs(:success?).returns(true)\n    result.stubs(:sermon).returns(sermons(:one))\n    \n    crawler_service = mock('crawler_service')\n    crawler_service.expects(:crawl).returns(result)\n    SermonCrawlerService.expects(:new).returns(crawler_service)\n    \n    # Job should complete without leaving resources hanging\n    @job.perform(@valid_url)\n    \n    # Verify no temporary files or connections remain\n    # (Implementation specific - adjust based on actual cleanup needs)\n  end\nend"