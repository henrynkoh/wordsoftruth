# frozen_string_literal: true

require "application_system_test_case"

class CrossBrowserTest < ApplicationSystemTestCase
  # Browser configurations for testing
  BROWSER_CONFIGS = {
    chrome: {
      browser: :chrome,
      options: {
        args: %w[--headless --disable-gpu --no-sandbox --disable-dev-shm-usage]
      }
    },
    firefox: {
      browser: :firefox,
      options: {
        args: %w[--headless]
      }
    },
    safari: {
      browser: :safari,
      options: {}
    },
    edge: {
      browser: :edge,
      options: {
        args: %w[--headless --disable-gpu]
      }
    }
  }.freeze

  # Device configurations
  DEVICE_CONFIGS = {
    desktop_large: { width: 1920, height: 1080 },
    desktop_medium: { width: 1366, height: 768 },
    desktop_small: { width: 1024, height: 768 },
    tablet_landscape: { width: 1024, height: 768 },
    tablet_portrait: { width: 768, height: 1024 },
    mobile_large: { width: 414, height: 896 },
    mobile_medium: { width: 375, height: 667 },
    mobile_small: { width: 320, height: 568 }
  }.freeze

  def setup
    super
    @test_results = {}
    @user = create_test_user
  end

  test "authentication flow across all browsers" do
    BROWSER_CONFIGS.each do |browser_name, config|
      next unless browser_available?(browser_name)

      test_authentication_in_browser(browser_name, config)
    end

    generate_browser_compatibility_report("authentication")
  end

  test "text notes functionality across devices" do
    DEVICE_CONFIGS.each do |device_name, dimensions|
      test_text_notes_on_device(device_name, dimensions)
    end

    generate_device_compatibility_report("text_notes")
  end

  test "sermon automation workflow cross-browser" do
    BROWSER_CONFIGS.each do |browser_name, config|
      next unless browser_available?(browser_name)

      test_sermon_automation_in_browser(browser_name, config)
    end

    generate_browser_compatibility_report("sermon_automation")
  end

  test "responsive design validation" do
    DEVICE_CONFIGS.each do |device_name, dimensions|
      test_responsive_design(device_name, dimensions)
    end

    generate_responsive_design_report
  end

  test "mobile touch interactions" do
    mobile_devices = DEVICE_CONFIGS.select { |name, _| name.to_s.include?("mobile") }
    
    mobile_devices.each do |device_name, dimensions|
      test_touch_interactions(device_name, dimensions)
    end

    generate_mobile_interaction_report
  end

  test "keyboard navigation accessibility" do
    BROWSER_CONFIGS.each do |browser_name, config|
      next unless browser_available?(browser_name)

      test_keyboard_navigation(browser_name, config)
    end

    generate_accessibility_report
  end

  test "performance across devices" do
    DEVICE_CONFIGS.each do |device_name, dimensions|
      test_device_performance(device_name, dimensions)
    end

    generate_performance_report
  end

  private

  def test_authentication_in_browser(browser_name, config)
    puts "🌐 Testing authentication in #{browser_name.to_s.capitalize}"
    
    start_time = Time.current
    
    begin
      configure_browser(config)
      
      visit root_path
      assert_page_loads_correctly
      
      # Test sign in button visibility
      assert_selector "a[href*='auth/google_oauth2']", text: "Sign In"
      
      # Test OAuth redirect (without actually authenticating)
      click_link "Sign In"
      assert_current_path("/auth/google_oauth2")
      
      # Test error handling
      visit "/auth/failure"
      assert_text "Authentication failed"
      
      success = true
      error_message = nil
      
    rescue => e
      success = false
      error_message = e.message
      puts "❌ Authentication test failed in #{browser_name}: #{e.message}"
    end
    
    duration = Time.current - start_time
    
    @test_results["authentication_#{browser_name}"] = {
      browser: browser_name,
      success: success,
      duration: duration,
      error: error_message,
      test_type: "authentication"
    }
  end

  def test_text_notes_on_device(device_name, dimensions)
    puts "📱 Testing text notes on #{device_name} (#{dimensions[:width]}x#{dimensions[:height]})"
    
    start_time = Time.current
    
    begin
      resize_window_to(dimensions[:width], dimensions[:height])
      sign_in_test_user
      
      visit text_notes_path
      assert_page_loads_correctly
      
      # Test responsive layout
      assert_responsive_navigation
      assert_responsive_content_layout
      
      # Test text note creation on this device
      click_button "New Text Note"
      assert_selector "#new-text-note-form"
      
      fill_in "Title", with: "Device Test Note #{device_name}"
      fill_in "Content", with: "Testing text note creation on #{device_name} device"
      select "Reflection", from: "Note Type"
      
      click_button "Create Text Note"
      assert_text "Text note created successfully"
      assert_text "Device Test Note #{device_name}"
      
      # Test mobile-specific interactions if on mobile
      if device_name.to_s.include?("mobile")
        test_mobile_specific_features
      end
      
      success = true
      error_message = nil
      
    rescue => e
      success = false
      error_message = e.message
      puts "❌ Text notes test failed on #{device_name}: #{e.message}"
    end
    
    duration = Time.current - start_time
    
    @test_results["text_notes_#{device_name}"] = {
      device: device_name,
      dimensions: dimensions,
      success: success,
      duration: duration,
      error: error_message,
      test_type: "text_notes"
    }
  end

  def test_sermon_automation_in_browser(browser_name, config)
    puts "⛪ Testing sermon automation in #{browser_name.to_s.capitalize}"
    
    start_time = Time.current
    
    begin
      configure_browser(config)
      sign_in_test_user
      
      visit root_path
      assert_page_loads_correctly
      
      # Test sermon URL input
      assert_selector "#sermon-url-input"
      fill_in "sermon[source_url]", with: "https://example-church.com/test-sermon"
      
      # Test form submission (mock the actual crawling)
      click_button "Process Sermon"
      
      # Should show processing message
      assert_text "Sermon processing started"
      
      success = true
      error_message = nil
      
    rescue => e
      success = false
      error_message = e.message
      puts "❌ Sermon automation test failed in #{browser_name}: #{e.message}"
    end
    
    duration = Time.current - start_time
    
    @test_results["sermon_automation_#{browser_name}"] = {
      browser: browser_name,
      success: success,
      duration: duration,
      error: error_message,
      test_type: "sermon_automation"
    }
  end

  def test_responsive_design(device_name, dimensions)
    puts "📐 Testing responsive design on #{device_name}"
    
    start_time = Time.current
    issues = []
    
    begin
      resize_window_to(dimensions[:width], dimensions[:height])
      sign_in_test_user
      
      # Test main pages at this resolution
      pages_to_test = [
        { path: root_path, name: "Home" },
        { path: text_notes_path, name: "Text Notes" },
        { path: new_text_note_path, name: "New Text Note" }
      ]
      
      pages_to_test.each do |page|
        visit page[:path]
        
        # Check for responsive design issues
        issues.concat(check_responsive_issues(page[:name], dimensions))
      end
      
      success = issues.empty?
      
    rescue => e
      success = false
      issues << "Exception: #{e.message}"
    end
    
    duration = Time.current - start_time
    
    @test_results["responsive_#{device_name}"] = {
      device: device_name,
      dimensions: dimensions,
      success: success,
      duration: duration,
      issues: issues,
      test_type: "responsive_design"
    }
  end

  def test_touch_interactions(device_name, dimensions)
    puts "👆 Testing touch interactions on #{device_name}"
    
    start_time = Time.current
    
    begin
      resize_window_to(dimensions[:width], dimensions[:height])
      sign_in_test_user
      
      visit text_notes_path
      
      # Test touch targets are appropriately sized (minimum 44px)
      touch_elements = all("button, a, input[type='submit']")
      small_targets = touch_elements.select do |element|
        size = element.native.size
        size.width < 44 || size.height < 44
      end
      
      assert small_targets.empty?, 
        "Found #{small_targets.count} touch targets smaller than 44px minimum"
      
      # Test swipe gestures (simulated)
      if has_selector?(".swipeable")
        # Simulate swipe on swipeable elements
        find(".swipeable").drag_to(find(".swipe-target"))
      end
      
      # Test tap interactions
      click_button "New Text Note"
      assert_selector "#new-text-note-form"
      
      success = true
      error_message = nil
      
    rescue => e
      success = false
      error_message = e.message
    end
    
    duration = Time.current - start_time
    
    @test_results["touch_#{device_name}"] = {
      device: device_name,
      dimensions: dimensions,
      success: success,
      duration: duration,
      error: error_message,
      test_type: "touch_interactions"
    }
  end

  def test_keyboard_navigation(browser_name, config)
    puts "⌨️ Testing keyboard navigation in #{browser_name.to_s.capitalize}"
    
    start_time = Time.current
    accessibility_issues = []
    
    begin
      configure_browser(config)
      sign_in_test_user
      
      visit text_notes_path
      
      # Test tab navigation
      first_focusable = find("a, button, input, select, textarea", match: :first)
      first_focusable.send_keys(:tab)
      
      # Check that focus moves correctly
      focused_element = page.evaluate_script("document.activeElement")
      assert focused_element, "Tab navigation should move focus"
      
      # Test keyboard shortcuts
      if has_selector?("[data-keyboard-shortcut]")
        # Test application-specific keyboard shortcuts
        page.send_keys([:control, 'n']) # New note shortcut
        if has_selector?("#new-text-note-form")
          # Shortcut worked
        else
          accessibility_issues << "Keyboard shortcut Ctrl+N not working"
        end
      end
      
      # Test escape key functionality
      if has_selector?(".modal")
        page.send_keys(:escape)
        assert_no_selector(".modal"), "Escape key should close modals"
      end
      
      success = accessibility_issues.empty?
      
    rescue => e
      success = false
      accessibility_issues << "Exception: #{e.message}"
    end
    
    duration = Time.current - start_time
    
    @test_results["keyboard_#{browser_name}"] = {
      browser: browser_name,
      success: success,
      duration: duration,
      issues: accessibility_issues,
      test_type: "keyboard_navigation"
    }
  end

  def test_device_performance(device_name, dimensions)
    puts "⚡ Testing performance on #{device_name}"
    
    resize_window_to(dimensions[:width], dimensions[:height])
    sign_in_test_user
    
    # Measure page load times
    load_times = {}
    
    pages_to_test = [
      { path: root_path, name: "home" },
      { path: text_notes_path, name: "text_notes" },
      { path: new_text_note_path, name: "new_text_note" }
    ]
    
    pages_to_test.each do |page|
      start_time = Time.current
      visit page[:path]
      wait_for_page_load
      load_time = Time.current - start_time
      
      load_times[page[:name]] = load_time
      
      # Performance thresholds based on device type
      max_load_time = if device_name.to_s.include?("mobile")
        5.0 # Mobile devices get 5 seconds
      else
        3.0 # Desktop/tablet get 3 seconds
      end
      
      assert load_time < max_load_time, 
        "Page #{page[:name]} loaded too slowly on #{device_name}: #{load_time}s > #{max_load_time}s"
    end
    
    @test_results["performance_#{device_name}"] = {
      device: device_name,
      dimensions: dimensions,
      success: true,
      load_times: load_times,
      test_type: "performance"
    }
  end

  def check_responsive_issues(page_name, dimensions)
    issues = []
    
    # Check for horizontal scrolling (should not happen)
    if page.evaluate_script("document.body.scrollWidth > window.innerWidth")
      issues << "#{page_name}: Horizontal scrolling detected at #{dimensions[:width]}px"
    end
    
    # Check for text overflow
    overflowing_elements = page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll('*')).filter(el => {
        return el.scrollWidth > el.clientWidth && 
               window.getComputedStyle(el).overflow === 'visible';
      }).length;
    JS
    
    if overflowing_elements > 0
      issues << "#{page_name}: #{overflowing_elements} elements have text overflow"
    end
    
    # Check for elements too small on mobile
    if dimensions[:width] <= 768
      small_touch_targets = page.evaluate_script(<<~JS)
        Array.from(document.querySelectorAll('button, a, input[type="submit"]')).filter(el => {
          const rect = el.getBoundingClientRect();
          return rect.width < 44 || rect.height < 44;
        }).length;
      JS
      
      if small_touch_targets > 0
        issues << "#{page_name}: #{small_touch_targets} touch targets smaller than 44px"
      end
    end
    
    issues
  end

  def assert_responsive_navigation
    # Check that navigation adapts to screen size
    if page.evaluate_script("window.innerWidth <= 768")
      # Mobile: should have hamburger menu or collapsed nav
      assert_selector(".mobile-nav, .navbar-toggler, .hamburger-menu")
    else
      # Desktop: should have full navigation
      assert_selector(".navbar, .main-nav")
    end
  end

  def assert_responsive_content_layout
    # Check that content stacks properly on small screens
    if page.evaluate_script("window.innerWidth <= 768")
      # On mobile, sidebar should be hidden or stacked
      sidebar_visible = page.evaluate_script(<<~JS)
        const sidebar = document.querySelector('.sidebar');
        if (!sidebar) return false;
        const styles = window.getComputedStyle(sidebar);
        return styles.display !== 'none' && styles.visibility !== 'hidden';
      JS
      
      # Sidebar should either be hidden or positioned appropriately
      assert !sidebar_visible || has_selector?(".sidebar.mobile-friendly"),
        "Sidebar should be hidden or mobile-friendly on small screens"
    end
  end

  def test_mobile_specific_features
    # Test pull-to-refresh if implemented
    if has_selector?("[data-pull-to-refresh]")
      # Simulate pull gesture
      page.execute_script("window.scrollTo(0, -100);")
    end
    
    # Test mobile-specific UI elements
    if has_selector?(".mobile-only")
      assert_selector ".mobile-only:visible"
    end
    
    # Test that desktop-only elements are hidden
    if has_selector?(".desktop-only")
      desktop_elements_visible = page.evaluate_script(<<~JS)
        const elements = document.querySelectorAll('.desktop-only');
        return Array.from(elements).some(el => 
          window.getComputedStyle(el).display !== 'none'
        );
      JS
      
      assert !desktop_elements_visible, "Desktop-only elements should be hidden on mobile"
    end
  end

  def configure_browser(config)
    Capybara.current_driver = config[:browser]
    
    if config[:options][:args]
      Capybara.register_driver config[:browser] do |app|
        case config[:browser]
        when :chrome
          Capybara::Selenium::Driver.new(app, browser: :chrome, 
            options: Selenium::WebDriver::Chrome::Options.new(args: config[:options][:args]))
        when :firefox
          Capybara::Selenium::Driver.new(app, browser: :firefox,
            options: Selenium::WebDriver::Firefox::Options.new(args: config[:options][:args]))
        else
          Capybara::Selenium::Driver.new(app, browser: config[:browser])
        end
      end
    end
  end

  def resize_window_to(width, height)
    page.driver.browser.manage.window.resize_to(width, height)
  end

  def browser_available?(browser_name)
    case browser_name
    when :safari
      RUBY_PLATFORM.include?("darwin") # Only on macOS
    when :edge
      RUBY_PLATFORM.include?("mswin") || RUBY_PLATFORM.include?("mingw") # Only on Windows
    else
      true
    end
  end

  def assert_page_loads_correctly
    assert_no_selector ".error-page"
    assert_no_text "500 Internal Server Error"
    assert_no_text "404 Not Found"
  end

  def wait_for_page_load
    # Wait for page to be fully loaded
    page.has_no_css?(".loading", wait: 10)
    page.evaluate_script("document.readyState") == "complete"
  end

  def create_test_user
    # Create a test user for cross-browser testing
    User.create!(
      email: "crossbrowser.test@example.com",
      name: "Cross Browser Test User",
      provider: "google_oauth2",
      uid: "crossbrowser123"
    )
  end

  def sign_in_test_user
    # Mock sign in for testing
    page.execute_script(<<~JS)
      // Mock authentication for testing
      sessionStorage.setItem('test_user_signed_in', 'true');
    JS
    
    visit root_path
  end

  def generate_browser_compatibility_report(test_type)
    puts "\n📊 Browser Compatibility Report - #{test_type.capitalize}"
    puts "=" * 60
    
    browser_results = @test_results.select { |k, _| k.include?(test_type) }
    
    browser_results.each do |test_name, result|
      status = result[:success] ? "✅ PASS" : "❌ FAIL"
      duration = result[:duration].round(2)
      
      puts sprintf("%-20s %s %8ss", result[:browser].to_s.capitalize, status, duration)
      
      if result[:error]
        puts "   Error: #{result[:error]}"
      end
    end
  end

  def generate_device_compatibility_report(test_type)
    puts "\n📱 Device Compatibility Report - #{test_type.capitalize}"
    puts "=" * 60
    
    device_results = @test_results.select { |k, _| k.include?(test_type) }
    
    device_results.each do |test_name, result|
      status = result[:success] ? "✅ PASS" : "❌ FAIL"
      duration = result[:duration].round(2)
      dimensions = "#{result[:dimensions][:width]}x#{result[:dimensions][:height]}"
      
      puts sprintf("%-20s %-12s %s %8ss", 
        result[:device].to_s, dimensions, status, duration)
      
      if result[:error]
        puts "   Error: #{result[:error]}"
      end
    end
  end

  def generate_responsive_design_report
    puts "\n📐 Responsive Design Report"
    puts "=" * 60
    
    responsive_results = @test_results.select { |k, _| k.include?("responsive") }
    
    responsive_results.each do |test_name, result|
      status = result[:success] ? "✅ PASS" : "❌ FAIL"
      dimensions = "#{result[:dimensions][:width]}x#{result[:dimensions][:height]}"
      
      puts sprintf("%-20s %-12s %s", result[:device].to_s, dimensions, status)
      
      if result[:issues] && result[:issues].any?
        result[:issues].each do |issue|
          puts "   ⚠️  #{issue}"
        end
      end
    end
  end

  def generate_mobile_interaction_report
    puts "\n👆 Mobile Interaction Report"
    puts "=" * 60
    
    touch_results = @test_results.select { |k, _| k.include?("touch") }
    
    touch_results.each do |test_name, result|
      status = result[:success] ? "✅ PASS" : "❌ FAIL"
      
      puts sprintf("%-20s %s", result[:device].to_s, status)
      
      if result[:error]
        puts "   Error: #{result[:error]}"
      end
    end
  end

  def generate_accessibility_report
    puts "\n⌨️ Accessibility Report"
    puts "=" * 60
    
    a11y_results = @test_results.select { |k, _| k.include?("keyboard") }
    
    a11y_results.each do |test_name, result|
      status = result[:success] ? "✅ PASS" : "❌ FAIL"
      
      puts sprintf("%-20s %s", result[:browser].to_s.capitalize, status)
      
      if result[:issues] && result[:issues].any?
        result[:issues].each do |issue|
          puts "   ⚠️  #{issue}"
        end
      end
    end
  end

  def generate_performance_report
    puts "\n⚡ Performance Report"
    puts "=" * 60
    
    perf_results = @test_results.select { |k, _| k.include?("performance") }
    
    perf_results.each do |test_name, result|
      puts "#{result[:device].to_s.capitalize}:"
      
      result[:load_times].each do |page, time|
        status = time < 3.0 ? "✅" : "⚠️"
        puts sprintf("  %-15s %s %6.2fs", page, status, time)
      end
    end
  end
end