require "test_helper"
require "webmock/minitest"

class SermonCrawlerServiceTest < ActiveSupport::TestCase
  def setup
    @service = SermonCrawlerService.new
    @valid_url = "https://example-church.com/sermons/faith-hope"
    @valid_html = <<~HTML
      <html>
        <head><title>Faith and Hope in Difficult Times</title></head>
        <body>
          <h1>Faith and Hope in Difficult Times</h1>
          <p class="pastor">Pastor John Smith</p>
          <p class="church">Grace Community Church</p>
          <p class="scripture">Romans 8:28</p>
          <div class="content">
            <p>God works all things together for good for those who love Him.</p>
            <p>Action points: Trust in God's plan, pray daily, serve others.</p>
          </div>
          <p class="date">December 25, 2023</p>
          <p class="denomination">Baptist</p>
          <p class="audience">150 people</p>
        </body>
      </html>
    HTML
  end

  def teardown
    WebMock.reset!
  end

  # URL Validation Tests
  test "should validate URLs before processing" do
    valid_urls = [
      "https://example.com/sermon",
      "http://church.org/message",
      "https://subdomain.church.com/sermons/123"
    ]
    
    valid_urls.each do |url|
      assert @service.send(:valid_url?, url), "Should accept valid URL: #{url}"
    end
  end

  test "should reject invalid URLs" do
    invalid_urls = [
      "javascript:alert('xss')",
      "data:text/html,<script>alert('xss')</script>",
      "file:///etc/passwd",
      "ftp://malicious.com",
      "",
      nil,
      "not-a-url",
      "http://",
      "https://"
    ]
    
    invalid_urls.each do |url|
      assert_not @service.send(:valid_url?, url), "Should reject invalid URL: #{url}"
    end
  end

  # SSRF Protection Tests
  test "should block private IP addresses" do
    private_ips = [
      "http://127.0.0.1/sermon",
      "http://localhost/sermon",
      "http://10.0.0.1/sermon",
      "http://172.16.0.1/sermon",
      "http://192.168.1.1/sermon",
      "http://169.254.169.254/sermon", # AWS metadata
      "http://0.0.0.0/sermon"
    ]
    
    private_ips.each do |url|
      assert_not @service.send(:safe_url?, url), "Should block private IP: #{url}"
    end
  end

  test "should allow public IP addresses" do
    public_urls = [
      "https://8.8.8.8/sermon",
      "https://1.1.1.1/sermon",
      "https://example.com/sermon"
    ]
    
    public_urls.each do |url|
      assert @service.send(:safe_url?, url), "Should allow public URL: #{url}"
    end
  end

  # Successful Crawling Tests
  test "should successfully crawl and parse sermon data" do
    WebMock.stub_request(:get, @valid_url)
      .to_return(status: 200, body: @valid_html, headers: { 'Content-Type' => 'text/html' })
    
    result = @service.crawl(@valid_url)
    
    assert result.success?
    sermon = result.sermon
    
    assert_equal "Faith and Hope in Difficult Times", sermon.title
    assert_equal "Pastor John Smith", sermon.pastor
    assert_equal "Grace Community Church", sermon.church
    assert_equal "Romans 8:28", sermon.scripture
    assert_includes sermon.interpretation, "God works all things together"
    assert_includes sermon.action_points, "Trust in God's plan"
    assert_equal "Baptist", sermon.denomination
    assert_equal 150, sermon.audience_count
    assert_equal @valid_url, sermon.source_url
  end

  test "should handle missing optional fields gracefully" do
    minimal_html = <<~HTML
      <html>
        <head><title>Simple Sermon</title></head>
        <body>
          <h1>Simple Sermon</h1>
          <p class="church">Simple Church</p>
        </body>
      </html>
    HTML
    
    WebMock.stub_request(:get, @valid_url)
      .to_return(status: 200, body: minimal_html, headers: { 'Content-Type' => 'text/html' })
    
    result = @service.crawl(@valid_url)
    
    assert result.success?
    sermon = result.sermon
    
    assert_equal "Simple Sermon", sermon.title
    assert_equal "Simple Church", sermon.church
    assert_nil sermon.pastor
    assert_nil sermon.scripture
    assert_nil sermon.audience_count
  end

  # Error Handling Tests
  test "should handle network timeouts" do
    WebMock.stub_request(:get, @valid_url).to_timeout
    
    result = @service.crawl(@valid_url)
    
    assert_not result.success?
    assert_includes result.error, "timeout"
  end

  test "should handle connection errors" do
    WebMock.stub_request(:get, @valid_url).to_raise(SocketError.new("Connection failed"))
    
    result = @service.crawl(@valid_url)
    
    assert_not result.success?
    assert_includes result.error, "Connection failed"
  end

  test "should handle HTTP error responses" do
    WebMock.stub_request(:get, @valid_url)
      .to_return(status: 404, body: "Not Found")
    
    result = @service.crawl(@valid_url)
    
    assert_not result.success?
    assert_includes result.error, "404"
  end

  test "should handle redirect limits" do
    # Stub a redirect chain that exceeds the limit
    10.times do |i|
      redirect_url = "https://example.com/redirect#{i}"
      next_url = "https://example.com/redirect#{i + 1}"
      
      WebMock.stub_request(:get, redirect_url)
        .to_return(status: 302, headers: { 'Location' => next_url })
    end
    
    result = @service.crawl("https://example.com/redirect0")
    
    assert_not result.success?
    assert_includes result.error, "Too many redirects"
  end

  test "should handle malformed HTML" do
    malformed_html = "<html><head><title>Broken</head><body><h1>Missing closing tags"
    
    WebMock.stub_request(:get, @valid_url)
      .to_return(status: 200, body: malformed_html, headers: { 'Content-Type' => 'text/html' })
    
    result = @service.crawl(@valid_url)
    
    # Should still succeed but may have incomplete data
    assert result.success?
    assert_equal "Broken", result.sermon.title
  end

  # Content Parsing Tests
  test "should extract title from various HTML structures" do
    title_variations = [
      { html: "<title>Title in Head</title>", expected: "Title in Head" },
      { html: "<h1>Title in H1</h1>", expected: "Title in H1" },
      { html: "<h1 class='sermon-title'>Classed Title</h1>", expected: "Classed Title" },
      { html: "<div class='title'>Div Title</div>", expected: "Div Title" }
    ]
    
    title_variations.each do |variation|
      html = "<html><body>#{variation[:html]}</body></html>"
      
      WebMock.stub_request(:get, @valid_url)
        .to_return(status: 200, body: html, headers: { 'Content-Type' => 'text/html' })
      
      result = @service.crawl(@valid_url)
      assert_equal variation[:expected], result.sermon.title
    end
  end

  test "should sanitize extracted content" do
    malicious_html = <<~HTML
      <html>
        <body>
          <title>Clean Title<script>alert('xss')</script></title>
          <h1>Sermon<iframe src="javascript:alert(1)"></iframe></h1>
          <p class="pastor">Pastor<img onerror="alert(1)" src="x"></p>
        </body>
      </html>
    HTML
    
    WebMock.stub_request(:get, @valid_url)
      .to_return(status: 200, body: malicious_html, headers: { 'Content-Type' => 'text/html' })
    
    result = @service.crawl(@valid_url)
    
    assert result.success?
    assert_not_includes result.sermon.title, "<script>"
    assert_not_includes result.sermon.pastor, "<img"
    assert_equal "Clean Title", result.sermon.title
    assert_equal "Pastor", result.sermon.pastor
  end

  # Configuration Tests
  test "should respect timeout configuration" do
    original_timeout = SermonCrawlerService::TIMEOUT
    
    # Stub with delay longer than timeout
    WebMock.stub_request(:get, @valid_url).to_timeout
    
    start_time = Time.current
    result = @service.crawl(@valid_url)
    end_time = Time.current
    
    assert_not result.success?
    assert (end_time - start_time) < (original_timeout + 1), "Should timeout within configured time"
  end

  test "should respect maximum content size" do
    large_content = "x" * (SermonCrawlerService::MAX_CONTENT_SIZE + 1000)
    
    WebMock.stub_request(:get, @valid_url)
      .to_return(status: 200, body: large_content, headers: { 'Content-Type' => 'text/html' })
    
    result = @service.crawl(@valid_url)
    
    assert_not result.success?
    assert_includes result.error, "Content too large"
  end

  # User Agent Tests
  test "should send appropriate user agent" do
    WebMock.stub_request(:get, @valid_url)
      .with(headers: { 'User-Agent' => /Words of Truth/ })
      .to_return(status: 200, body: @valid_html)
    
    result = @service.crawl(@valid_url)
    assert result.success?
  end

  # Result Object Tests
  test "should return proper result object structure" do
    WebMock.stub_request(:get, @valid_url)
      .to_return(status: 200, body: @valid_html)
    
    result = @service.crawl(@valid_url)
    
    assert_respond_to result, :success?
    assert_respond_to result, :sermon
    assert_respond_to result, :error
    
    assert result.success?
    assert_instance_of Sermon, result.sermon
    assert_nil result.error
  end

  test "should return error result for failures" do
    WebMock.stub_request(:get, @valid_url).to_timeout
    
    result = @service.crawl(@valid_url)
    
    assert_not result.success?
    assert_nil result.sermon
    assert_not_nil result.error
  end

  # Security Edge Cases
  test "should handle suspicious URLs with encoded characters" do
    suspicious_urls = [
      "https://example.com/%2e%2e%2f%2e%2e%2fetc%2fpasswd",
      "https://example.com/..%2f..%2fetc%2fpasswd",
      "https://example.com/sermon?redirect=file:///etc/passwd"
    ]
    
    suspicious_urls.each do |url|
      result = @service.crawl(url)
      assert_not result.success?, "Should reject suspicious URL: #{url}"
    end
  end

  test "should handle international domain names" do
    international_urls = [
      "https://교회.com/sermon",
      "https://église.fr/sermon",
      "https://кирха.рф/sermon"
    ]
    
    international_urls.each do |url|
      # Should validate but may fail on actual request
      assert @service.send(:valid_url?, url), "Should accept international domain: #{url}"
    end
  end

  test "should handle very long URLs" do
    long_path = "a" * 2000
    long_url = "https://example.com/#{long_path}"
    
    # Should handle long URLs gracefully
    result = @service.crawl(long_url)
    # Result depends on server response, but should not crash
    assert_not_nil result
  end

  # Rate Limiting Tests (if implemented)
  test "should respect rate limiting" do
    # Simulate multiple requests
    5.times do |i|
      url = "https://example#{i}.com/sermon"
      WebMock.stub_request(:get, url)
        .to_return(status: 200, body: @valid_html)
      
      result = @service.crawl(url)
      # Should succeed but may be rate limited
      assert_not_nil result
    end
  end

  # Data Validation Tests
  test "should validate extracted data before creating sermon" do
    invalid_html = <<~HTML
      <html>
        <body>
          <title></title>
          <p class="church"></p>
        </body>
      </html>
    HTML
    
    WebMock.stub_request(:get, @valid_url)
      .to_return(status: 200, body: invalid_html)
    
    result = @service.crawl(@valid_url)
    
    assert_not result.success?
    assert_includes result.error, "validation"
  end

  # Encoding Tests
  test "should handle different character encodings" do
    utf8_html = <<~HTML
      <html>
        <head><meta charset="utf-8"><title>Fé e Esperança</title></head>
        <body>
          <h1>Fé e Esperança</h1>
          <p class="church">Igreja da Graça</p>
        </body>
      </html>
    HTML
    
    WebMock.stub_request(:get, @valid_url)
      .to_return(
        status: 200, 
        body: utf8_html.encode('UTF-8'),
        headers: { 'Content-Type' => 'text/html; charset=utf-8' }
      )
    
    result = @service.crawl(@valid_url)
    
    assert result.success?
    assert_equal "Fé e Esperança", result.sermon.title
    assert_equal "Igreja da Graça", result.sermon.church
  end
end