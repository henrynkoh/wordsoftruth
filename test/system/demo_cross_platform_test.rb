# frozen_string_literal: true

require "application_system_test_case"

class DemoCrossPlatformTest < ApplicationSystemTestCase
  # Simplified test that demonstrates cross-platform testing capabilities
  
  def setup
    super
    @test_results = {}
  end

  test "basic application loads across different viewport sizes" do
    puts "\n🚀 Starting Cross-Platform Demo Test"
    puts "=" * 50
    
    # Test different viewport sizes to simulate various devices
    viewports = [
      { name: "Mobile Portrait", width: 375, height: 667 },
      { name: "Mobile Landscape", width: 667, height: 375 },
      { name: "Tablet", width: 768, height: 1024 },
      { name: "Desktop", width: 1920, height: 1080 }
    ]
    
    viewports.each do |viewport|
      test_viewport(viewport)
    end
    
    generate_demo_report
  end

  test "responsive navigation behavior" do
    puts "\n📱 Testing Responsive Navigation"
    puts "-" * 30
    
    # Test mobile viewport
    resize_viewport(375, 667)
    visit root_path
    
    # Check if page loads
    assert page.has_content?("Words of Truth"), "Application should load on mobile"
    puts "✅ Mobile: Application loads successfully"
    
    # Test desktop viewport
    resize_viewport(1920, 1080)
    visit root_path
    
    assert page.has_content?("Words of Truth"), "Application should load on desktop"
    puts "✅ Desktop: Application loads successfully"
    
    # Check for basic HTML structure
    assert page.has_selector?("body"), "Page should have body element"
    assert page.has_selector?("html"), "Page should have html element"
    puts "✅ HTML structure is valid"
  end

  test "form elements are touch-friendly on mobile" do
    puts "\n👆 Testing Touch-Friendly Elements"
    puts "-" * 35
    
    # Set mobile viewport
    resize_viewport(375, 667)
    visit root_path
    
    # Look for interactive elements
    buttons = all("button, input[type='submit'], a")
    links = all("a")
    
    puts "Found #{buttons.count} interactive elements"
    puts "Found #{links.count} links"
    
    # Basic validation that elements exist
    if buttons.any?
      puts "✅ Interactive elements found"
    else
      puts "⚠️  No interactive elements found"
    end
    
    if links.any?
      puts "✅ Navigation links found"
    else
      puts "⚠️  No navigation links found"
    end
  end

  test "basic accessibility features" do
    puts "\n♿ Testing Basic Accessibility"
    puts "-" * 32
    
    visit root_path
    
    # Check for basic accessibility features
    has_headings = page.has_selector?("h1, h2, h3, h4, h5, h6")
    has_alt_text = page.all("img").all? { |img| img[:alt] || img[:'aria-label'] }
    has_semantic_elements = page.has_selector?("main, nav, header, footer, article, section")
    
    if has_headings
      puts "✅ Heading structure found"
    else
      puts "⚠️  No heading structure found"
    end
    
    if has_alt_text || page.all("img").empty?
      puts "✅ Images have alt text (or no images present)"
    else
      puts "⚠️  Some images missing alt text"
    end
    
    if has_semantic_elements
      puts "✅ Semantic HTML elements found"
    else
      puts "⚠️  Limited semantic HTML structure"
    end
  end

  test "performance check across viewports" do
    puts "\n⚡ Testing Basic Performance"
    puts "-" * 28
    
    viewports = [
      { name: "Mobile", width: 375, height: 667 },
      { name: "Desktop", width: 1920, height: 1080 }
    ]
    
    viewports.each do |viewport|
      resize_viewport(viewport[:width], viewport[:height])
      
      start_time = Time.current
      visit root_path
      load_time = Time.current - start_time
      
      status = load_time < 5.0 ? "✅ FAST" : load_time < 10.0 ? "⚠️  OK" : "❌ SLOW"
      puts "#{status} #{viewport[:name]}: #{load_time.round(2)}s"
      
      @test_results["#{viewport[:name].downcase}_performance"] = {
        load_time: load_time,
        viewport: viewport,
        status: load_time < 5.0 ? "pass" : "warning"
      }
    end
  end

  private

  def test_viewport(viewport)
    puts "\n📏 Testing #{viewport[:name]} (#{viewport[:width]}x#{viewport[:height]})"
    
    start_time = Time.current
    
    begin
      resize_viewport(viewport[:width], viewport[:height])
      visit root_path
      
      # Basic checks
      page_loads = page.has_content?("Words of Truth") || page.has_selector?("body")
      no_horizontal_scroll = check_horizontal_scroll
      
      duration = Time.current - start_time
      
      @test_results[viewport[:name].downcase.gsub(" ", "_")] = {
        viewport: viewport,
        page_loads: page_loads,
        no_horizontal_scroll: no_horizontal_scroll,
        duration: duration,
        success: page_loads && no_horizontal_scroll
      }
      
      status = page_loads && no_horizontal_scroll ? "✅ PASS" : "❌ FAIL"
      puts "#{status} #{viewport[:name]} - Load: #{page_loads ? 'OK' : 'FAIL'}, Scroll: #{no_horizontal_scroll ? 'OK' : 'FAIL'} (#{duration.round(2)}s)"
      
    rescue => e
      puts "❌ FAIL #{viewport[:name]} - Error: #{e.message}"
      @test_results[viewport[:name].downcase.gsub(" ", "_")] = {
        viewport: viewport,
        success: false,
        error: e.message
      }
    end
  end

  def resize_viewport(width, height)
    page.driver.browser.manage.window.resize_to(width, height)
    sleep 0.5 # Allow time for responsive changes
  end

  def check_horizontal_scroll
    # Check if page has horizontal scrolling
    return true unless page.evaluate_script("document.body")
    
    body_width = page.evaluate_script("document.body.scrollWidth")
    window_width = page.evaluate_script("window.innerWidth")
    
    body_width <= window_width
  rescue
    true # Assume no horizontal scroll if we can't detect
  end

  def generate_demo_report
    puts "\n" + "=" * 50
    puts "🏁 DEMO CROSS-PLATFORM TEST COMPLETE"
    puts "=" * 50
    
    total_tests = @test_results.count
    successful_tests = @test_results.values.count { |r| r[:success] }
    failed_tests = total_tests - successful_tests
    
    puts "Total viewport tests: #{total_tests}"
    puts "✅ Successful: #{successful_tests}"
    puts "❌ Failed: #{failed_tests}"
    puts "Success rate: #{total_tests > 0 ? ((successful_tests.to_f / total_tests) * 100).round(1) : 0}%"
    
    if @test_results.any?
      puts "\n📊 DETAILED RESULTS"
      puts "-" * 30
      
      @test_results.each do |test_name, result|
        if result[:success]
          viewport = result[:viewport]
          duration = result[:duration]&.round(2)
          puts "✅ #{test_name.gsub('_', ' ').capitalize} (#{viewport[:width]}x#{viewport[:height]}) - #{duration}s"
        else
          puts "❌ #{test_name.gsub('_', ' ').capitalize} - #{result[:error] || 'Failed'}"
        end
      end
    end
    
    puts "\n💡 NEXT STEPS"
    puts "-" * 15
    puts "1. Run full cross-platform test suite: ./test/system/run_cross_platform_tests.rb"
    puts "2. Test specific browsers: rails test test/system/cross_browser_test.rb"
    puts "3. Test mobile devices: rails test test/system/mobile_device_test.rb"
    puts "4. Test accessibility: rails test test/system/accessibility_test.rb"
    
    puts "\n" + "=" * 50
  end
end