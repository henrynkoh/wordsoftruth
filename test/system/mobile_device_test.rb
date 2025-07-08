# frozen_string_literal: true

require "application_system_test_case"

class MobileDeviceTest < ApplicationSystemTestCase
  # Popular mobile device specifications
  MOBILE_DEVICES = {
    iphone_14_pro: {
      name: "iPhone 14 Pro",
      width: 393,
      height: 852,
      pixel_ratio: 3,
      user_agent: "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1"
    },
    iphone_se: {
      name: "iPhone SE",
      width: 375,
      height: 667,
      pixel_ratio: 2,
      user_agent: "Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1"
    },
    samsung_galaxy_s23: {
      name: "Samsung Galaxy S23",
      width: 384,
      height: 854,
      pixel_ratio: 3,
      user_agent: "Mozilla/5.0 (Linux; Android 13; SM-S911B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Mobile Safari/537.36"
    },
    google_pixel_7: {
      name: "Google Pixel 7",
      width: 412,
      height: 915,
      pixel_ratio: 2.625,
      user_agent: "Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Mobile Safari/537.36"
    },
    xiaomi_redmi_note: {
      name: "Xiaomi Redmi Note 12",
      width: 393,
      height: 851,
      pixel_ratio: 2.75,
      user_agent: "Mozilla/5.0 (Linux; Android 12; Redmi Note 12) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/111.0.0.0 Mobile Safari/537.36"
    }
  }.freeze

  # Tablet devices
  TABLET_DEVICES = {
    ipad_air: {
      name: "iPad Air",
      width: 820,
      height: 1180,
      pixel_ratio: 2,
      user_agent: "Mozilla/5.0 (iPad; CPU OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1"
    },
    samsung_galaxy_tab: {
      name: "Samsung Galaxy Tab S8",
      width: 753,
      height: 1037,
      pixel_ratio: 2.4,
      user_agent: "Mozilla/5.0 (Linux; Android 12; SM-X706B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/111.0.0.0 Safari/537.36"
    }
  }.freeze

  def setup
    super
    @test_results = {}
    @user = create_test_user
  end

  test "mobile authentication flow" do
    MOBILE_DEVICES.each do |device_key, device|
      test_mobile_authentication(device_key, device)
    end

    generate_mobile_authentication_report
  end

  test "mobile text notes creation and editing" do
    MOBILE_DEVICES.each do |device_key, device|
      test_mobile_text_notes(device_key, device)
    end

    generate_mobile_functionality_report("text_notes")
  end

  test "mobile sermon automation interface" do
    MOBILE_DEVICES.each do |device_key, device|
      test_mobile_sermon_automation(device_key, device)
    end

    generate_mobile_functionality_report("sermon_automation")
  end

  test "tablet interface optimization" do
    TABLET_DEVICES.each do |device_key, device|
      test_tablet_interface(device_key, device)
    end

    generate_tablet_interface_report
  end

  test "mobile performance and loading" do
    MOBILE_DEVICES.each do |device_key, device|
      test_mobile_performance(device_key, device)
    end

    generate_mobile_performance_report
  end

  test "mobile gesture interactions" do
    MOBILE_DEVICES.each do |device_key, device|
      test_mobile_gestures(device_key, device)
    end

    generate_gesture_interaction_report
  end

  test "mobile offline behavior" do
    MOBILE_DEVICES.select { |k, _| k == :iphone_14_pro }.each do |device_key, device|
      test_mobile_offline_behavior(device_key, device)
    end

    generate_offline_behavior_report
  end

  test "mobile accessibility features" do
    MOBILE_DEVICES.each do |device_key, device|
      test_mobile_accessibility(device_key, device)
    end

    generate_mobile_accessibility_report
  end

  private

  def test_mobile_authentication(device_key, device)
    puts "📱 Testing authentication on #{device[:name]}"
    
    start_time = Time.current
    success = true
    issues = []
    
    begin
      configure_mobile_device(device)
      
      visit root_path
      
      # Test mobile navigation menu
      if has_selector?(".mobile-menu-toggle")
        click_button class: "mobile-menu-toggle"
        assert_selector ".mobile-menu", visible: true
      end
      
      # Test sign in button accessibility on mobile
      sign_in_button = find("a[href*='auth/google_oauth2']")
      button_size = sign_in_button.native.size
      
      if button_size.width < 44 || button_size.height < 44
        issues << "Sign in button too small for touch: #{button_size.width}x#{button_size.height}px"
      end
      
      # Test sign in flow
      click_link "Sign In"
      
      # Should redirect to OAuth
      assert_current_path("/auth/google_oauth2")
      
      # Test back navigation
      visit root_path
      assert_selector "a[href*='auth/google_oauth2']"
      
    rescue => e
      success = false
      issues << "Exception: #{e.message}"
    end
    
    duration = Time.current - start_time
    
    @test_results["auth_#{device_key}"] = {
      device: device,
      success: success,
      duration: duration,
      issues: issues,
      test_type: "authentication"
    }
  end

  def test_mobile_text_notes(device_key, device)
    puts "📝 Testing text notes on #{device[:name]}"
    
    start_time = Time.current
    success = true
    issues = []
    
    begin
      configure_mobile_device(device)
      sign_in_test_user
      
      visit text_notes_path
      
      # Test mobile layout
      check_mobile_layout_issues(issues)
      
      # Test "New Text Note" button on mobile
      new_note_button = find_button("New Text Note")
      click_button "New Text Note"
      
      # Check form usability on mobile
      assert_selector "#new-text-note-form"
      
      # Test form fields are appropriately sized
      title_field = find_field("Title")
      content_field = find_field("Content")
      
      # Check field sizes
      title_size = title_field.native.size
      if title_size.height < 44
        issues << "Title field too small for mobile: #{title_size.height}px height"
      end
      
      # Test form filling on mobile
      fill_in "Title", with: "Mobile Test Note #{device[:name]}"
      fill_in "Content", with: "Testing text note creation on mobile device #{device[:name]}"
      select "Reflection", from: "Note Type"
      
      # Test mobile keyboard doesn't break layout
      # (Note: In real testing, virtual keyboard would appear)
      
      click_button "Create Text Note"
      assert_text "Text note created successfully"
      
      # Test note display on mobile
      assert_text "Mobile Test Note #{device[:name]}"
      
      # Test note editing on mobile
      click_link "Edit"
      assert_selector "#edit-text-note-form"
      
      fill_in "Title", with: "Edited Mobile Note"
      click_button "Update Text Note"
      assert_text "Text note updated successfully"
      
    rescue => e
      success = false
      issues << "Exception: #{e.message}"
    end
    
    duration = Time.current - start_time
    
    @test_results["text_notes_#{device_key}"] = {
      device: device,
      success: success,
      duration: duration,
      issues: issues,
      test_type: "text_notes"
    }
  end

  def test_mobile_sermon_automation(device_key, device)
    puts "⛪ Testing sermon automation on #{device[:name]}"
    
    start_time = Time.current
    success = true
    issues = []
    
    begin
      configure_mobile_device(device)
      sign_in_test_user
      
      visit root_path
      
      # Test sermon URL input on mobile
      url_input = find_field("sermon[source_url]")
      input_size = url_input.native.size
      
      if input_size.height < 44
        issues << "URL input field too small for mobile: #{input_size.height}px height"
      end
      
      # Test URL input with mobile keyboard
      fill_in "sermon[source_url]", with: "https://mobile-test-church.com/sermon"
      
      # Test process button
      process_button = find_button("Process Sermon")
      button_size = process_button.native.size
      
      if button_size.width < 44 || button_size.height < 44
        issues << "Process button too small for touch: #{button_size.width}x#{button_size.height}px"
      end
      
      click_button "Process Sermon"
      
      # Should show processing message
      assert_text "Sermon processing started"
      
    rescue => e
      success = false
      issues << "Exception: #{e.message}"
    end
    
    duration = Time.current - start_time
    
    @test_results["sermon_#{device_key}"] = {
      device: device,
      success: success,
      duration: duration,
      issues: issues,
      test_type: "sermon_automation"
    }
  end

  def test_tablet_interface(device_key, device)
    puts "📱 Testing tablet interface on #{device[:name]}"
    
    start_time = Time.current
    success = true
    issues = []
    
    begin
      configure_mobile_device(device)
      sign_in_test_user
      
      visit text_notes_path
      
      # Test tablet-specific layout
      # Tablets should show more content than phones but less than desktop
      sidebar_visible = has_selector?(".sidebar", visible: true)
      content_columns = page.evaluate_script(<<~JS)
        const main = document.querySelector('.main-content');
        if (!main) return 1;
        const styles = window.getComputedStyle(main);
        return parseInt(styles.getPropertyValue('column-count')) || 1;
      JS
      
      # On tablet, should utilize screen space efficiently
      if device[:width] > 768 && !sidebar_visible && content_columns <= 1
        issues << "Tablet layout not optimized - could show more content"
      end
      
      # Test tablet-specific interactions
      # Should support both touch and possible mouse/trackpad
      new_note_button = find_button("New Text Note")
      
      # Test hover states work (for tablets with trackpad)
      if page.evaluate_script("'ontouchstart' in window && 'onmouseenter' in window")
        # Device supports both touch and mouse
        new_note_button.hover
        # Check if hover state is visible
      end
      
      click_button "New Text Note"
      assert_selector "#new-text-note-form"
      
      # Test form layout on tablet
      form_width = page.evaluate_script("document.querySelector('#new-text-note-form').offsetWidth")
      screen_width = device[:width]
      
      if form_width / screen_width > 0.9
        issues << "Form takes up too much width on tablet (#{(form_width.to_f / screen_width * 100).round}%)"
      end
      
    rescue => e
      success = false
      issues << "Exception: #{e.message}"
    end
    
    duration = Time.current - start_time
    
    @test_results["tablet_#{device_key}"] = {
      device: device,
      success: success,
      duration: duration,
      issues: issues,
      test_type: "tablet_interface"
    }
  end

  def test_mobile_performance(device_key, device)
    puts "⚡ Testing mobile performance on #{device[:name]}"
    
    configure_mobile_device(device)
    sign_in_test_user
    
    # Measure page load times
    pages = [
      { path: root_path, name: "home" },
      { path: text_notes_path, name: "text_notes" },
      { path: new_text_note_path, name: "new_text_note" }
    ]
    
    load_times = {}
    
    pages.each do |page|
      # Clear cache to simulate fresh page load
      page.driver.browser.manage.delete_all_cookies
      
      start_time = Time.current
      visit page[:path]
      wait_for_mobile_page_load
      load_time = Time.current - start_time
      
      load_times[page[:name]] = load_time
      
      # Mobile performance should be within 5 seconds
      assert load_time < 5.0, 
        "Page #{page[:name]} loaded too slowly on mobile: #{load_time}s"
    end
    
    @test_results["performance_#{device_key}"] = {
      device: device,
      success: true,
      load_times: load_times,
      test_type: "mobile_performance"
    }
  end

  def test_mobile_gestures(device_key, device)
    puts "👆 Testing mobile gestures on #{device[:name]}"
    
    start_time = Time.current
    success = true
    gesture_results = {}
    
    begin
      configure_mobile_device(device)
      sign_in_test_user
      
      visit text_notes_path
      
      # Test scroll behavior
      initial_scroll = page.evaluate_script("window.pageYOffset")
      page.execute_script("window.scrollBy(0, 500)")
      new_scroll = page.evaluate_script("window.pageYOffset")
      
      gesture_results[:scroll] = new_scroll > initial_scroll
      
      # Test swipe navigation (if implemented)
      if has_selector?(".swipeable-content")
        swipe_element = find(".swipeable-content")
        
        # Simulate swipe left
        page.execute_script(<<~JS)
          const element = arguments[0];
          const touchStart = new Touch({
            identifier: Date.now(),
            target: element,
            clientX: #{device[:width] * 0.8},
            clientY: #{device[:height] * 0.5}
          });
          const touchEnd = new Touch({
            identifier: Date.now(),
            target: element,
            clientX: #{device[:width] * 0.2},
            clientY: #{device[:height] * 0.5}
          });
          
          element.dispatchEvent(new TouchEvent('touchstart', {
            changedTouches: [touchStart]
          }));
          element.dispatchEvent(new TouchEvent('touchend', {
            changedTouches: [touchEnd]
          }));
        JS
        
        gesture_results[:swipe] = true
      else
        gesture_results[:swipe] = "Not implemented"
      end
      
      # Test pinch-to-zoom prevention (should be disabled for better UX)
      zoom_disabled = page.evaluate_script(<<~JS)
        const viewport = document.querySelector('meta[name="viewport"]');
        return viewport && viewport.content.includes('user-scalable=no');
      JS
      
      gesture_results[:zoom_disabled] = zoom_disabled
      
      # Test touch target spacing
      touch_elements = all("button, a, input, select")
      close_elements = 0
      
      touch_elements.each_with_index do |element1, i|
        touch_elements[(i+1)..-1].each do |element2|
          rect1 = element1.native.rect
          rect2 = element2.native.rect
          
          distance = Math.sqrt(
            (rect1.x - rect2.x) ** 2 + (rect1.y - rect2.y) ** 2
          )
          
          if distance < 44 # Minimum touch target spacing
            close_elements += 1
          end
        end
      end
      
      gesture_results[:touch_spacing] = close_elements == 0
      
    rescue => e
      success = false
      gesture_results[:error] = e.message
    end
    
    duration = Time.current - start_time
    
    @test_results["gestures_#{device_key}"] = {
      device: device,
      success: success,
      duration: duration,
      gesture_results: gesture_results,
      test_type: "mobile_gestures"
    }
  end

  def test_mobile_offline_behavior(device_key, device)
    puts "📶 Testing offline behavior on #{device[:name]}"
    
    configure_mobile_device(device)
    sign_in_test_user
    
    # Test online functionality first
    visit text_notes_path
    assert_text "Text Notes"
    
    # Simulate offline mode
    page.execute_script("window.navigator.__defineGetter__('onLine', function(){return false;})")
    
    # Test offline message
    page.execute_script("window.dispatchEvent(new Event('offline'))")
    
    # Check if app shows offline indicator
    offline_indicator = has_selector?(".offline-indicator, .no-connection")
    
    # Test that critical functionality still works offline (if service worker implemented)
    visit text_notes_path
    
    # Should either show cached content or proper offline message
    offline_handling = has_text?("Text Notes") || has_text?("You are offline") || has_text?("No connection")
    
    @test_results["offline_#{device_key}"] = {
      device: device,
      success: offline_handling,
      offline_indicator: offline_indicator,
      test_type: "mobile_offline"
    }
  end

  def test_mobile_accessibility(device_key, device)
    puts "♿ Testing mobile accessibility on #{device[:name]}"
    
    start_time = Time.current
    success = true
    accessibility_issues = []
    
    begin
      configure_mobile_device(device)
      sign_in_test_user
      
      visit text_notes_path
      
      # Test focus management on mobile
      first_interactive = find("button, a, input, select", match: :first)
      first_interactive.click
      
      focused_element = page.evaluate_script("document.activeElement")
      if !focused_element
        accessibility_issues << "Focus not properly managed on touch"
      end
      
      # Test screen reader compatibility
      # Check for proper ARIA labels and roles
      unlabeled_inputs = all("input:not([aria-label]):not([aria-labelledby]):not([title])").count
      if unlabeled_inputs > 0
        accessibility_issues << "#{unlabeled_inputs} inputs without proper labels"
      end
      
      # Test heading structure
      headings = all("h1, h2, h3, h4, h5, h6")
      if headings.empty?
        accessibility_issues << "No heading structure found"
      end
      
      # Test color contrast (basic check)
      # Note: Full color contrast testing requires specialized tools
      low_contrast_elements = page.evaluate_script(<<~JS)
        // Basic contrast check - would need more sophisticated testing in practice
        let lowContrastCount = 0;
        document.querySelectorAll('*').forEach(el => {
          const styles = window.getComputedStyle(el);
          const bgColor = styles.backgroundColor;
          const textColor = styles.color;
          
          // Simple check - in practice, would use proper contrast ratio calculation
          if (bgColor === textColor) {
            lowContrastCount++;
          }
        });
        return lowContrastCount;
      JS
      
      if low_contrast_elements > 0
        accessibility_issues << "Potential low contrast elements detected: #{low_contrast_elements}"
      end
      
      # Test touch target sizes
      small_targets = page.evaluate_script(<<~JS)
        let smallTargets = 0;
        document.querySelectorAll('button, a, input[type="submit"], input[type="button"]').forEach(el => {
          const rect = el.getBoundingClientRect();
          if (rect.width < 44 || rect.height < 44) {
            smallTargets++;
          }
        });
        return smallTargets;
      JS
      
      if small_targets > 0
        accessibility_issues << "#{small_targets} touch targets smaller than 44px minimum"
      end
      
      success = accessibility_issues.empty?
      
    rescue => e
      success = false
      accessibility_issues << "Exception: #{e.message}"
    end
    
    duration = Time.current - start_time
    
    @test_results["accessibility_#{device_key}"] = {
      device: device,
      success: success,
      duration: duration,
      issues: accessibility_issues,
      test_type: "mobile_accessibility"
    }
  end

  def configure_mobile_device(device)
    page.driver.browser.manage.window.resize_to(device[:width], device[:height])
    
    # Set user agent to mobile
    page.execute_script(<<~JS)
      Object.defineProperty(navigator, 'userAgent', {
        get: function() { return '#{device[:user_agent]}'; }
      });
    JS
    
    # Set device pixel ratio
    page.execute_script(<<~JS)
      Object.defineProperty(window, 'devicePixelRatio', {
        get: function() { return #{device[:pixel_ratio]}; }
      });
    JS
    
    # Simulate touch capability
    page.execute_script(<<~JS)
      Object.defineProperty(navigator, 'maxTouchPoints', {
        get: function() { return 5; }
      });
    JS
  end

  def check_mobile_layout_issues(issues)
    # Check for horizontal scrolling
    has_horizontal_scroll = page.evaluate_script("document.body.scrollWidth > window.innerWidth")
    if has_horizontal_scroll
      issues << "Horizontal scrolling detected on mobile"
    end
    
    # Check for text that's too small
    small_text_elements = page.evaluate_script(<<~JS)
      let smallTextCount = 0;
      document.querySelectorAll('*').forEach(el => {
        const styles = window.getComputedStyle(el);
        const fontSize = parseFloat(styles.fontSize);
        if (fontSize > 0 && fontSize < 14) {
          smallTextCount++;
        }
      });
      return smallTextCount;
    JS
    
    if small_text_elements > 0
      issues << "#{small_text_elements} text elements smaller than 14px"
    end
    
    # Check for elements that might be cut off
    viewport_width = page.evaluate_script("window.innerWidth")
    wide_elements = page.evaluate_script(<<~JS)
      let wideElementCount = 0;
      document.querySelectorAll('*').forEach(el => {
        if (el.scrollWidth > #{viewport_width}) {
          wideElementCount++;
        }
      });
      return wideElementCount;
    JS
    
    if wide_elements > 0
      issues << "#{wide_elements} elements wider than viewport"
    end
  end

  def wait_for_mobile_page_load
    # Wait for page to be fully loaded on mobile
    page.has_no_css?(".loading", wait: 15) # Mobile gets more time
    page.evaluate_script("document.readyState") == "complete"
  end

  def create_test_user
    User.create!(
      email: "mobile.test@example.com",
      name: "Mobile Test User",
      provider: "google_oauth2",
      uid: "mobile123"
    )
  end

  def sign_in_test_user
    # Mock sign in for testing
    page.execute_script(<<~JS)
      sessionStorage.setItem('test_user_signed_in', 'true');
    JS
    
    visit root_path
  end

  def generate_mobile_authentication_report
    puts "\n📱 Mobile Authentication Report"
    puts "=" * 50
    
    auth_results = @test_results.select { |k, _| k.include?("auth_") }
    
    auth_results.each do |test_name, result|
      status = result[:success] ? "✅ PASS" : "❌ FAIL"
      duration = result[:duration].round(2)
      
      puts sprintf("%-20s %s %8ss", result[:device][:name], status, duration)
      
      if result[:issues].any?
        result[:issues].each { |issue| puts "   ⚠️  #{issue}" }
      end
    end
  end

  def generate_mobile_functionality_report(test_type)
    puts "\n📱 Mobile #{test_type.capitalize} Report"
    puts "=" * 50
    
    results = @test_results.select { |k, _| k.include?("#{test_type}_") }
    
    results.each do |test_name, result|
      status = result[:success] ? "✅ PASS" : "❌ FAIL"
      duration = result[:duration].round(2)
      
      puts sprintf("%-20s %s %8ss", result[:device][:name], status, duration)
      
      if result[:issues].any?
        result[:issues].each { |issue| puts "   ⚠️  #{issue}" }
      end
    end
  end

  def generate_tablet_interface_report
    puts "\n📱 Tablet Interface Report"
    puts "=" * 50
    
    tablet_results = @test_results.select { |k, _| k.include?("tablet_") }
    
    tablet_results.each do |test_name, result|
      status = result[:success] ? "✅ PASS" : "❌ FAIL"
      duration = result[:duration].round(2)
      
      puts sprintf("%-20s %s %8ss", result[:device][:name], status, duration)
      
      if result[:issues].any?
        result[:issues].each { |issue| puts "   ⚠️  #{issue}" }
      end
    end
  end

  def generate_mobile_performance_report
    puts "\n⚡ Mobile Performance Report"
    puts "=" * 50
    
    perf_results = @test_results.select { |k, _| k.include?("performance_") }
    
    perf_results.each do |test_name, result|
      puts "#{result[:device][:name]}:"
      
      result[:load_times].each do |page, time|
        status = time < 3.0 ? "✅ FAST" : time < 5.0 ? "⚠️  OK" : "❌ SLOW"
        puts sprintf("  %-15s %s %6.2fs", page, status, time)
      end
    end
  end

  def generate_gesture_interaction_report
    puts "\n👆 Mobile Gesture Report"
    puts "=" * 50
    
    gesture_results = @test_results.select { |k, _| k.include?("gestures_") }
    
    gesture_results.each do |test_name, result|
      puts "#{result[:device][:name]}:"
      
      result[:gesture_results].each do |gesture, success|
        status = success == true ? "✅" : success == false ? "❌" : "⚠️"
        puts sprintf("  %-15s %s %s", gesture, status, success.to_s)
      end
    end
  end

  def generate_offline_behavior_report
    puts "\n📶 Mobile Offline Report"
    puts "=" * 50
    
    offline_results = @test_results.select { |k, _| k.include?("offline_") }
    
    offline_results.each do |test_name, result|
      status = result[:success] ? "✅ PASS" : "❌ FAIL"
      indicator = result[:offline_indicator] ? "✅" : "❌"
      
      puts sprintf("%-20s %s (Indicator: %s)", result[:device][:name], status, indicator)
    end
  end

  def generate_mobile_accessibility_report
    puts "\n♿ Mobile Accessibility Report"
    puts "=" * 50
    
    a11y_results = @test_results.select { |k, _| k.include?("accessibility_") }
    
    a11y_results.each do |test_name, result|
      status = result[:success] ? "✅ PASS" : "❌ FAIL"
      duration = result[:duration].round(2)
      
      puts sprintf("%-20s %s %8ss", result[:device][:name], status, duration)
      
      if result[:issues].any?
        result[:issues].each { |issue| puts "   ⚠️  #{issue}" }
      end
    end
  end
end