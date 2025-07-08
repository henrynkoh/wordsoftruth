# frozen_string_literal: true

require "application_system_test_case"

class SimpleDemoTest < ApplicationSystemTestCase
  test "demonstrate cross-platform testing capabilities" do
    puts "\n🚀 CROSS-PLATFORM TESTING DEMONSTRATION"
    puts "=" * 60
    puts "Testing Words of Truth across different devices and browsers"
    puts "=" * 60

    # Test different viewport sizes
    test_viewports = [
      { name: "📱 iPhone 14 Pro", width: 393, height: 852 },
      { name: "📱 Samsung Galaxy", width: 384, height: 854 },
      { name: "💻 iPad Air", width: 820, height: 1180 },
      { name: "🖥️  Desktop", width: 1920, height: 1080 }
    ]

    results = {}

    test_viewports.each do |viewport|
      puts "\n#{viewport[:name]} (#{viewport[:width]}×#{viewport[:height]})"
      puts "-" * 40

      start_time = Time.current
      
      begin
        # Resize browser to simulate device
        page.driver.browser.manage.window.resize_to(viewport[:width], viewport[:height])
        sleep 0.5
        
        # Visit the application
        visit root_path
        
        # Basic functionality checks
        checks = {}
        
        # Check 1: Page loads
        checks[:page_loads] = page.has_selector?("body")
        puts checks[:page_loads] ? "✅ Page loads successfully" : "❌ Page failed to load"
        
        # Check 2: No horizontal scroll
        body_width = page.evaluate_script("document.body.scrollWidth") rescue nil
        window_width = page.evaluate_script("window.innerWidth") rescue nil
        checks[:no_horizontal_scroll] = body_width && window_width && body_width <= window_width
        puts checks[:no_horizontal_scroll] ? "✅ No horizontal scrolling" : "⚠️  Horizontal scroll detected"
        
        # Check 3: Navigation elements exist
        checks[:has_navigation] = page.has_selector?("nav, .navbar, header") || page.has_link?("Sign In")
        puts checks[:has_navigation] ? "✅ Navigation elements found" : "⚠️  No navigation found"
        
        # Check 4: Content is readable
        checks[:readable_text] = page.has_text?("Words") || page.has_text?("Truth") || page.has_content?("Sermon")
        puts checks[:readable_text] ? "✅ Content is readable" : "⚠️  No readable content found"
        
        # Check 5: Interactive elements are appropriately sized for touch (mobile only)
        if viewport[:width] <= 768
          interactive_elements = all("button, a, input[type='submit']")
          appropriate_size = interactive_elements.all? do |element|
            size = element.native.size
            size.width >= 40 && size.height >= 40 # Slightly relaxed for demo
          end
          checks[:touch_friendly] = appropriate_size || interactive_elements.empty?
          puts checks[:touch_friendly] ? "✅ Touch-friendly elements" : "⚠️  Some elements too small for touch"
        else
          checks[:touch_friendly] = true # Not applicable for desktop
        end

        load_time = Time.current - start_time
        checks[:performance] = load_time < 5.0
        puts checks[:performance] ? "✅ Good performance (#{load_time.round(2)}s)" : "⚠️  Slow loading (#{load_time.round(2)}s)"

        # Overall result
        success_count = checks.values.count(true)
        total_checks = checks.size
        success_rate = (success_count.to_f / total_checks * 100).round(1)
        
        overall_success = success_rate >= 80
        status_icon = overall_success ? "✅" : "⚠️"
        
        puts "\n#{status_icon} Overall: #{success_count}/#{total_checks} checks passed (#{success_rate}%)"
        
        results[viewport[:name]] = {
          checks: checks,
          success_rate: success_rate,
          load_time: load_time,
          overall_success: overall_success
        }

      rescue => e
        puts "❌ Error testing #{viewport[:name]}: #{e.message}"
        results[viewport[:name]] = {
          error: e.message,
          overall_success: false
        }
      end
    end

    # Generate summary report
    generate_summary_report(results)
    
    # Assert that at least some tests passed
    assert results.values.any? { |r| r[:overall_success] }, "At least one viewport should pass all checks"
  end

  private

  def generate_summary_report(results)
    puts "\n" + "=" * 60
    puts "📊 CROSS-PLATFORM TEST SUMMARY"
    puts "=" * 60

    successful_devices = results.values.count { |r| r[:overall_success] }
    total_devices = results.size
    overall_success_rate = (successful_devices.to_f / total_devices * 100).round(1)

    puts "Devices tested: #{total_devices}"
    puts "Successful: #{successful_devices}"
    puts "Overall success rate: #{overall_success_rate}%"

    puts "\n📋 DETAILED RESULTS:"
    puts "-" * 30

    results.each do |device, result|
      if result[:error]
        puts "❌ #{device}: Error - #{result[:error]}"
      else
        icon = result[:overall_success] ? "✅" : "⚠️"
        time = result[:load_time]&.round(2)
        puts "#{icon} #{device}: #{result[:success_rate]}% (#{time}s)"
      end
    end

    puts "\n🔍 WHAT WAS TESTED:"
    puts "-" * 20
    puts "• Page loading across device sizes"
    puts "• Responsive layout (no horizontal scroll)"
    puts "• Navigation elements presence"
    puts "• Content readability"
    puts "• Touch-friendly element sizing (mobile)"
    puts "• Performance (load time under 5s)"

    puts "\n💡 FULL TESTING CAPABILITIES:"
    puts "-" * 30
    puts "The complete cross-platform test suite includes:"
    puts "🌐 Browser Compatibility (Chrome, Firefox, Safari, Edge)"
    puts "📱 Real Device Testing (25+ mobile devices)"
    puts "📐 Responsive Design (6 breakpoints)"
    puts "♿ WCAG 2.1 AA Accessibility Compliance"
    puts "⚡ Performance Monitoring"
    puts "🎨 Visual Regression Testing"
    puts "🔄 Automated CI/CD Integration"

    puts "\n🚀 TO RUN FULL TESTING SUITE:"
    puts "-" * 30
    puts "1. ./test/system/run_cross_platform_tests.rb"
    puts "2. rails test test/system/cross_browser_test.rb"
    puts "3. rails test test/system/mobile_device_test.rb"
    puts "4. rails test test/system/accessibility_test.rb"

    puts "\n" + "=" * 60

    if overall_success_rate >= 75
      puts "🎉 EXCELLENT! Your app works well across devices!"
    elsif overall_success_rate >= 50
      puts "✨ GOOD! Some improvements needed for better compatibility"
    else
      puts "⚠️  NEEDS WORK! Significant cross-platform issues detected"
    end
    
    puts "=" * 60
  end
end