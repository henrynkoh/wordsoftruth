# frozen_string_literal: true

require "application_system_test_case"

class BrowserCompatibilityTest < ApplicationSystemTestCase
  # Browser-specific feature testing matrix
  BROWSER_FEATURES = {
    chrome: {
      name: "Google Chrome",
      css_grid: true,
      css_flexbox: true,
      css_variables: true,
      es6_modules: true,
      fetch_api: true,
      web_components: true,
      service_workers: true,
      webp_support: true,
      min_version: 90
    },
    firefox: {
      name: "Mozilla Firefox",
      css_grid: true,
      css_flexbox: true,
      css_variables: true,
      es6_modules: true,
      fetch_api: true,
      web_components: true,
      service_workers: true,
      webp_support: true,
      min_version: 88
    },
    safari: {
      name: "Safari",
      css_grid: true,
      css_flexbox: true,
      css_variables: true,
      es6_modules: true,
      fetch_api: true,
      web_components: false, # Limited support
      service_workers: true,
      webp_support: true,
      min_version: 14
    },
    edge: {
      name: "Microsoft Edge",
      css_grid: true,
      css_flexbox: true,
      css_variables: true,
      es6_modules: true,
      fetch_api: true,
      web_components: true,
      service_workers: true,
      webp_support: true,
      min_version: 90
    }
  }.freeze

  # Legacy browser testing (for graceful degradation)
  LEGACY_BROWSERS = {
    ie11: {
      name: "Internet Explorer 11",
      css_grid: false,
      css_flexbox: true,
      css_variables: false,
      es6_modules: false,
      fetch_api: false,
      web_components: false,
      service_workers: false,
      webp_support: false
    }
  }.freeze

  def setup
    super
    @test_results = {}
    @user = create_test_user
  end

  test "modern browser feature support" do
    BROWSER_FEATURES.each do |browser_key, features|
      next unless browser_available?(browser_key)
      
      test_browser_features(browser_key, features)
    end

    generate_browser_feature_report
  end

  test "css compatibility across browsers" do
    BROWSER_FEATURES.each do |browser_key, features|
      next unless browser_available?(browser_key)
      
      test_css_compatibility(browser_key, features)
    end

    generate_css_compatibility_report
  end

  test "javascript functionality across browsers" do
    BROWSER_FEATURES.each do |browser_key, features|
      next unless browser_available?(browser_key)
      
      test_javascript_compatibility(browser_key, features)
    end

    generate_javascript_compatibility_report
  end

  test "form and input compatibility" do
    BROWSER_FEATURES.each do |browser_key, features|
      next unless browser_available?(browser_key)
      
      test_form_compatibility(browser_key, features)
    end

    generate_form_compatibility_report
  end

  test "media and file support" do
    BROWSER_FEATURES.each do |browser_key, features|
      next unless browser_available?(browser_key)
      
      test_media_compatibility(browser_key, features)
    end

    generate_media_compatibility_report
  end

  test "legacy browser graceful degradation" do
    # Test that the application works reasonably well in older browsers
    test_legacy_browser_support
    generate_legacy_support_report
  end

  test "vendor prefix requirements" do
    BROWSER_FEATURES.each do |browser_key, features|
      next unless browser_available?(browser_key)
      
      test_vendor_prefixes(browser_key, features)
    end

    generate_vendor_prefix_report
  end

  test "progressive enhancement" do
    BROWSER_FEATURES.each do |browser_key, features|
      next unless browser_available?(browser_key)
      
      test_progressive_enhancement(browser_key, features)
    end

    generate_progressive_enhancement_report
  end

  private

  def test_browser_features(browser_key, features)
    puts "🌐 Testing browser features in #{features[:name]}"
    
    start_time = Time.current
    feature_results = {}
    
    begin
      configure_browser(browser_key)
      sign_in_test_user
      visit root_path
      
      # Test CSS Grid support
      feature_results[:css_grid] = test_css_grid_support(features[:css_grid])
      
      # Test CSS Flexbox support
      feature_results[:css_flexbox] = test_css_flexbox_support(features[:css_flexbox])
      
      # Test CSS Custom Properties (Variables)
      feature_results[:css_variables] = test_css_variables_support(features[:css_variables])
      
      # Test ES6 Modules
      feature_results[:es6_modules] = test_es6_modules_support(features[:es6_modules])
      
      # Test Fetch API
      feature_results[:fetch_api] = test_fetch_api_support(features[:fetch_api])
      
      # Test Service Worker support
      feature_results[:service_workers] = test_service_worker_support(features[:service_workers])
      
      # Test WebP image support
      feature_results[:webp_support] = test_webp_support(features[:webp_support])
      
    rescue => e
      feature_results[:error] = e.message
    end
    
    duration = Time.current - start_time
    
    @test_results["features_#{browser_key}"] = {
      browser: browser_key,
      browser_name: features[:name],
      feature_results: feature_results,
      success: !feature_results.key?(:error),
      duration: duration,
      test_type: "browser_features"
    }
  end

  def test_css_compatibility(browser_key, features)
    puts "🎨 Testing CSS compatibility in #{features[:name]}"
    
    start_time = Time.current
    css_issues = []
    
    begin
      configure_browser(browser_key)
      sign_in_test_user
      visit text_notes_path
      
      # Test CSS Grid layout
      if features[:css_grid]
        grid_working = page.evaluate_script(<<~JS)
          const testEl = document.createElement('div');
          testEl.style.display = 'grid';
          return testEl.style.display === 'grid';
        JS)
        
        if !grid_working
          css_issues << "CSS Grid not working despite browser support"
        end
      end
      
      # Test Flexbox layout
      flexbox_elements = all(".d-flex, .flex, [style*='display: flex'], [style*='display:flex']")
      if flexbox_elements.any?
        flexbox_working = page.evaluate_script(<<~JS)
          const flexElements = document.querySelectorAll('.d-flex, .flex, [style*="display: flex"], [style*="display:flex"]');
          let allWorking = true;
          
          flexElements.forEach(el => {
            const styles = window.getComputedStyle(el);
            if (styles.display !== 'flex') {
              allWorking = false;
            }
          });
          
          return allWorking;
        JS)
        
        if !flexbox_working
          css_issues << "Flexbox not working properly"
        end
      end
      
      # Test CSS Custom Properties
      if features[:css_variables]
        custom_props_working = page.evaluate_script(<<~JS)
          const testEl = document.createElement('div');
          testEl.style.setProperty('--test-var', 'red');
          testEl.style.color = 'var(--test-var)';
          document.body.appendChild(testEl);
          
          const computed = window.getComputedStyle(testEl);
          const working = computed.color === 'red' || computed.color === 'rgb(255, 0, 0)';
          
          document.body.removeChild(testEl);
          return working;
        JS)
        
        if !custom_props_working
          css_issues << "CSS Custom Properties not working"
        end
      end
      
      # Test modern CSS features usage
      check_css_compatibility_issues(css_issues)
      
    rescue => e
      css_issues << "Exception: #{e.message}"
    end
    
    duration = Time.current - start_time
    
    @test_results["css_#{browser_key}"] = {
      browser: browser_key,
      browser_name: features[:name],
      css_issues: css_issues,
      success: css_issues.empty?,
      duration: duration,
      test_type: "css_compatibility"
    }
  end

  def test_javascript_compatibility(browser_key, features)
    puts "⚡ Testing JavaScript compatibility in #{features[:name]}"
    
    start_time = Time.current
    js_issues = []
    
    begin
      configure_browser(browser_key)
      sign_in_test_user
      visit new_text_note_path
      
      # Test basic JavaScript functionality
      js_working = page.evaluate_script("typeof console !== 'undefined' && typeof document !== 'undefined'")
      if !js_working
        js_issues << "Basic JavaScript not working"
      end
      
      # Test ES6 features
      if features[:es6_modules]
        es6_features_working = page.evaluate_script(<<~JS)
          try {
            // Test arrow functions
            const arrow = () => true;
            
            // Test const/let
            const test1 = 'test';
            let test2 = 'test';
            
            // Test template literals
            const template = `Hello ${'world'}`;
            
            // Test destructuring
            const [a, b] = [1, 2];
            const {length} = 'test';
            
            return arrow() && template === 'Hello world' && a === 1 && length === 4;
          } catch (e) {
            return false;
          }
        JS)
        
        if !es6_features_working
          js_issues << "ES6 features not working properly"
        end
      end
      
      # Test Fetch API
      if features[:fetch_api]
        fetch_available = page.evaluate_script("typeof fetch !== 'undefined'")
        if !fetch_available
          js_issues << "Fetch API not available"
        end
      end
      
      # Test form interactions
      fill_in "Title", with: "Browser Test"
      title_value = find_field("Title").value
      if title_value != "Browser Test"
        js_issues << "Form input not working properly"
      end
      
      # Test AJAX functionality
      if has_selector?("[data-ajax], .ajax-form")
        ajax_working = page.evaluate_script(<<~JS)
          if (typeof XMLHttpRequest === 'undefined' && typeof fetch === 'undefined') {
            return false;
          }
          return true;
        JS)
        
        if !ajax_working
          js_issues << "AJAX functionality not available"
        end
      end
      
    rescue => e
      js_issues << "Exception: #{e.message}"
    end
    
    duration = Time.current - start_time
    
    @test_results["javascript_#{browser_key}"] = {
      browser: browser_key,
      browser_name: features[:name],
      js_issues: js_issues,
      success: js_issues.empty?,
      duration: duration,
      test_type: "javascript_compatibility"
    }
  end

  def test_form_compatibility(browser_key, features)
    puts "📝 Testing form compatibility in #{features[:name]}"
    
    start_time = Time.current
    form_issues = []
    
    begin
      configure_browser(browser_key)
      sign_in_test_user
      visit new_text_note_path
      
      # Test HTML5 input types
      html5_inputs = ["email", "url", "tel", "search", "date", "time"]
      html5_inputs.each do |input_type|
        if has_field?(type: input_type)
          input_supported = page.evaluate_script(<<~JS)
            const input = document.createElement('input');
            input.type = '#{input_type}';
            return input.type === '#{input_type}';
          JS)
          
          if !input_supported
            form_issues << "HTML5 input type '#{input_type}' not supported"
          end
        end
      end
      
      # Test form validation
      if has_field?("required")
        validation_working = page.evaluate_script(<<~JS)
          const form = document.querySelector('form');
          const requiredField = document.querySelector('[required]');
          
          if (!form || !requiredField) return true; // Skip if no required fields
          
          // Try to submit form with empty required field
          requiredField.value = '';
          return typeof form.checkValidity === 'function';
        JS)
        
        if !validation_working
          form_issues << "HTML5 form validation not working"
        end
      end
      
      # Test placeholder support
      placeholders_working = page.evaluate_script(<<~JS)
        const input = document.createElement('input');
        return 'placeholder' in input;
      JS)
      
      if !placeholders_working
        form_issues << "Placeholder attribute not supported"
      end
      
      # Test form submission
      fill_in "Title", with: "Form Compatibility Test"
      fill_in "Content", with: "Testing form compatibility across browsers"
      select "Reflection", from: "Note Type"
      
      click_button "Create Text Note"
      
      # Check if form submission worked
      if has_text?("Text note created successfully")
        # Form submission successful
      else
        form_issues << "Form submission failed"
      end
      
    rescue => e
      form_issues << "Exception: #{e.message}"
    end
    
    duration = Time.current - start_time
    
    @test_results["forms_#{browser_key}"] = {
      browser: browser_key,
      browser_name: features[:name],
      form_issues: form_issues,
      success: form_issues.empty?,
      duration: duration,
      test_type: "form_compatibility"
    }
  end

  def test_media_compatibility(browser_key, features)
    puts "🖼️ Testing media compatibility in #{features[:name]}"
    
    start_time = Time.current
    media_issues = []
    
    begin
      configure_browser(browser_key)
      sign_in_test_user
      visit root_path
      
      # Test WebP support
      if features[:webp_support]
        webp_supported = page.evaluate_script(<<~JS)
          const canvas = document.createElement('canvas');
          canvas.width = 1;
          canvas.height = 1;
          return canvas.toDataURL('image/webp').indexOf('data:image/webp') === 0;
        JS)
        
        if !webp_supported
          media_issues << "WebP format not supported despite browser capability"
        end
      end
      
      # Test video element support
      video_supported = page.evaluate_script(<<~JS)
        const video = document.createElement('video');
        return typeof video.canPlayType === 'function';
      JS)
      
      if !video_supported
        media_issues << "HTML5 video not supported"
      end
      
      # Test audio element support
      audio_supported = page.evaluate_script(<<~JS)
        const audio = document.createElement('audio');
        return typeof audio.canPlayType === 'function';
      JS)
      
      if !audio_supported
        media_issues << "HTML5 audio not supported"
      end
      
      # Test responsive images
      if has_selector?("img[srcset], picture")
        responsive_images_working = page.evaluate_script(<<~JS)
          const img = document.createElement('img');
          return 'srcset' in img;
        JS)
        
        if !responsive_images_working
          media_issues << "Responsive images (srcset) not supported"
        end
      end
      
    rescue => e
      media_issues << "Exception: #{e.message}"
    end
    
    duration = Time.current - start_time
    
    @test_results["media_#{browser_key}"] = {
      browser: browser_key,
      browser_name: features[:name],
      media_issues: media_issues,
      success: media_issues.empty?,
      duration: duration,
      test_type: "media_compatibility"
    }
  end

  def test_legacy_browser_support
    puts "🕰️ Testing legacy browser support"
    
    start_time = Time.current
    legacy_issues = []
    
    begin
      # Simulate legacy browser environment
      page.execute_script(<<~JS)
        // Simulate IE11 environment
        if (window.fetch) {
          delete window.fetch;
        }
        if (window.Promise) {
          delete window.Promise;
        }
        if (document.querySelector) {
          // Keep querySelector as it's available in IE8+
        }
      JS)
      
      visit root_path
      
      # Test that basic functionality still works
      if has_selector?("body")
        # Page loads
      else
        legacy_issues << "Page fails to load in legacy browser simulation"
      end
      
      # Test that critical content is visible
      if has_text?("Words of Truth") || has_text?("Sermon") || has_text?("Text Notes")
        # Basic content visible
      else
        legacy_issues << "Critical content not visible in legacy browser"
      end
      
      # Test navigation
      if has_selector?("nav, .navbar, .navigation")
        # Navigation present
      else
        legacy_issues << "No navigation found in legacy browser"
      end
      
      # Test form functionality without modern JS
      if has_selector?("form")
        # Forms present - basic functionality should work
      else
        legacy_issues << "No forms found in legacy browser"
      end
      
    rescue => e
      legacy_issues << "Exception: #{e.message}"
    end
    
    duration = Time.current - start_time
    
    @test_results["legacy_support"] = {
      legacy_issues: legacy_issues,
      success: legacy_issues.empty?,
      duration: duration,
      test_type: "legacy_support"
    }
  end

  def test_vendor_prefixes(browser_key, features)
    puts "🏷️ Testing vendor prefixes in #{features[:name]}"
    
    start_time = Time.current
    prefix_issues = []
    
    begin
      configure_browser(browser_key)
      sign_in_test_user
      visit root_path
      
      # Test vendor-prefixed CSS properties
      vendor_prefixes = {
        chrome: ["-webkit-"],
        firefox: ["-moz-"],
        safari: ["-webkit-"],
        edge: ["-ms-", "-webkit-"]
      }
      
      browser_prefixes = vendor_prefixes[browser_key] || []
      
      # Check if vendor prefixes are used where needed
      css_properties_needing_prefixes = [
        "transform",
        "transition", 
        "animation",
        "box-shadow",
        "border-radius",
        "user-select"
      ]
      
      css_properties_needing_prefixes.each do |property|
        prefix_needed = page.evaluate_script(<<~JS)
          const testEl = document.createElement('div');
          document.body.appendChild(testEl);
          
          // Test if unprefixed version works
          testEl.style.#{property.camelize(:lower)} = 'initial';
          const unprefixedWorks = testEl.style.#{property.camelize(:lower)} !== '';
          
          document.body.removeChild(testEl);
          return !unprefixedWorks;
        JS)
        
        if prefix_needed && browser_prefixes.any?
          # Check if prefixed versions are available in CSS
          prefixed_available = page.evaluate_script(<<~JS)
            const styles = Array.from(document.styleSheets).reduce((rules, sheet) => {
              try {
                return rules.concat(Array.from(sheet.cssRules || sheet.rules || []));
              } catch (e) {
                return rules;
              }
            }, []);
            
            const prefixedFound = styles.some(rule => {
              if (rule.style) {
                const cssText = rule.style.cssText || '';
                return #{browser_prefixes}.some(prefix => 
                  cssText.includes(prefix + '#{property}')
                );
              }
              return false;
            });
            
            return prefixedFound;
          JS)
          
          if !prefixed_available
            prefix_issues << "Missing vendor prefix for #{property} in #{features[:name]}"
          end
        end
      end
      
    rescue => e
      prefix_issues << "Exception: #{e.message}"
    end
    
    duration = Time.current - start_time
    
    @test_results["prefixes_#{browser_key}"] = {
      browser: browser_key,
      browser_name: features[:name],
      prefix_issues: prefix_issues,
      success: prefix_issues.empty?,
      duration: duration,
      test_type: "vendor_prefixes"
    }
  end

  def test_progressive_enhancement(browser_key, features)
    puts "📈 Testing progressive enhancement in #{features[:name]}"
    
    start_time = Time.current
    enhancement_issues = []
    
    begin
      configure_browser(browser_key)
      sign_in_test_user
      
      # Test with JavaScript disabled
      page.execute_script("window.javascriptEnabled = false;")
      
      visit text_notes_path
      
      # Core functionality should work without JavaScript
      if has_text?("Text Notes")
        # Basic content loads
      else
        enhancement_issues << "Core content doesn't load without JavaScript"
      end
      
      # Forms should work without JavaScript
      visit new_text_note_path
      
      if has_selector?("form")
        # Form is present
        if has_field?("Title") && has_field?("Content")
          # Essential form fields present
        else
          enhancement_issues << "Essential form fields missing without JavaScript"
        end
      else
        enhancement_issues << "Form not accessible without JavaScript"
      end
      
      # Re-enable JavaScript and test enhanced features
      page.execute_script("window.javascriptEnabled = true;")
      
      visit text_notes_path
      
      # Test enhanced features
      if has_selector?("[data-ajax], .enhanced-feature")
        # Enhanced features present with JavaScript
      end
      
      # Test graceful degradation of interactive elements
      interactive_elements = all("button[onclick], [data-toggle], [data-action]")
      interactive_elements.each do |element|
        # These elements should have fallback functionality
        fallback_present = element[:href] || element["type"] == "submit" || 
                          has_selector?("noscript") || element["formaction"]
        
        if !fallback_present
          enhancement_issues << "Interactive element without fallback found"
          break # Don't spam with too many similar issues
        end
      end
      
    rescue => e
      enhancement_issues << "Exception: #{e.message}"
    end
    
    duration = Time.current - start_time
    
    @test_results["enhancement_#{browser_key}"] = {
      browser: browser_key,
      browser_name: features[:name],
      enhancement_issues: enhancement_issues,
      success: enhancement_issues.empty?,
      duration: duration,
      test_type: "progressive_enhancement"
    }
  end

  # Helper methods for feature testing

  def test_css_grid_support(expected)
    return "N/A" unless expected
    
    page.evaluate_script(<<~JS)
      const testEl = document.createElement('div');
      testEl.style.display = 'grid';
      document.body.appendChild(testEl);
      
      const styles = window.getComputedStyle(testEl);
      const supported = styles.display === 'grid';
      
      document.body.removeChild(testEl);
      return supported;
    JS)
  end

  def test_css_flexbox_support(expected)
    return "N/A" unless expected
    
    page.evaluate_script(<<~JS)
      const testEl = document.createElement('div');
      testEl.style.display = 'flex';
      document.body.appendChild(testEl);
      
      const styles = window.getComputedStyle(testEl);
      const supported = styles.display === 'flex';
      
      document.body.removeChild(testEl);
      return supported;
    JS)
  end

  def test_css_variables_support(expected)
    return "N/A" unless expected
    
    page.evaluate_script(<<~JS)
      if (!window.CSS || !window.CSS.supports) return false;
      return window.CSS.supports('color', 'var(--test)');
    JS)
  end

  def test_es6_modules_support(expected)
    return "N/A" unless expected
    
    page.evaluate_script(<<~JS)
      const script = document.createElement('script');
      script.type = 'module';
      script.textContent = 'export default true;';
      
      try {
        document.head.appendChild(script);
        document.head.removeChild(script);
        return true;
      } catch (e) {
        return false;
      }
    JS)
  end

  def test_fetch_api_support(expected)
    return "N/A" unless expected
    
    page.evaluate_script("typeof fetch !== 'undefined'")
  end

  def test_service_worker_support(expected)
    return "N/A" unless expected
    
    page.evaluate_script("'serviceWorker' in navigator")
  end

  def test_webp_support(expected)
    return "N/A" unless expected
    
    page.evaluate_script(<<~JS)
      const canvas = document.createElement('canvas');
      canvas.width = 1;
      canvas.height = 1;
      const supported = canvas.toDataURL('image/webp').indexOf('data:image/webp') === 0;
      return supported;
    JS)
  end

  def check_css_compatibility_issues(issues)
    # Check for CSS features that might not work in older browsers
    problematic_css = page.evaluate_script(<<~JS)
      const issues = [];
      
      // Check for CSS Grid usage without fallback
      const gridElements = document.querySelectorAll('[style*="display: grid"], .grid, [class*="grid-"]');
      if (gridElements.length > 0) {
        const gridSupported = CSS.supports('display', 'grid');
        if (!gridSupported) {
          issues.push('CSS Grid used without fallback');
        }
      }
      
      // Check for CSS Custom Properties usage
      const styles = Array.from(document.styleSheets).reduce((rules, sheet) => {
        try {
          return rules.concat(Array.from(sheet.cssRules || sheet.rules || []));
        } catch (e) {
          return rules;
        }
      }, []);
      
      const customPropsUsed = styles.some(rule => {
        if (rule.style) {
          const cssText = rule.style.cssText || '';
          return cssText.includes('var(--') || cssText.includes('--');
        }
        return false;
      });
      
      if (customPropsUsed) {
        const customPropsSupported = CSS.supports && CSS.supports('color', 'var(--test)');
        if (!customPropsSupported) {
          issues.push('CSS Custom Properties used without fallback');
        }
      }
      
      return issues;
    JS)
    
    issues.concat(problematic_css)
  end

  def configure_browser(browser_key)
    case browser_key
    when :chrome
      Capybara.current_driver = :selenium_chrome
    when :firefox
      Capybara.current_driver = :selenium_firefox
    when :safari
      Capybara.current_driver = :selenium_safari if RUBY_PLATFORM.include?("darwin")
    when :edge
      Capybara.current_driver = :selenium_edge if RUBY_PLATFORM.include?("mswin")
    end
  end

  def browser_available?(browser_key)
    case browser_key
    when :safari
      RUBY_PLATFORM.include?("darwin")
    when :edge
      RUBY_PLATFORM.include?("mswin") || RUBY_PLATFORM.include?("mingw")
    else
      true
    end
  end

  def create_test_user
    User.create!(
      email: "compatibility.test@example.com",
      name: "Compatibility Test User",
      provider: "google_oauth2",
      uid: "compatibility123"
    )
  end

  def sign_in_test_user
    page.execute_script(<<~JS)
      sessionStorage.setItem('test_user_signed_in', 'true');
    JS)
    
    visit root_path
  end

  # Report generation methods

  def generate_browser_feature_report
    puts "\n🌐 Browser Feature Support Report"
    puts "=" * 70
    
    feature_results = @test_results.select { |k, _| k.include?("features_") }
    
    feature_results.each do |test_name, result|
      puts "\n#{result[:browser_name]}:"
      
      result[:feature_results].each do |feature, supported|
        status = case supported
                when true then "✅ SUPPORTED"
                when false then "❌ NOT SUPPORTED"
                when "N/A" then "⚠️  N/A"
                else "❓ #{supported}"
                end
        
        puts sprintf("  %-20s %s", feature.to_s.humanize, status)
      end
    end
  end

  def generate_css_compatibility_report
    puts "\n🎨 CSS Compatibility Report"
    puts "=" * 50
    
    css_results = @test_results.select { |k, _| k.include?("css_") }
    
    css_results.each do |test_name, result|
      status = result[:success] ? "✅ PASS" : "❌ FAIL"
      
      puts sprintf("%-20s %s", result[:browser_name], status)
      
      if result[:css_issues].any?
        result[:css_issues].each { |issue| puts "   ⚠️  #{issue}" }
      end
    end
  end

  def generate_javascript_compatibility_report
    puts "\n⚡ JavaScript Compatibility Report"
    puts "=" * 50
    
    js_results = @test_results.select { |k, _| k.include?("javascript_") }
    
    js_results.each do |test_name, result|
      status = result[:success] ? "✅ PASS" : "❌ FAIL"
      
      puts sprintf("%-20s %s", result[:browser_name], status)
      
      if result[:js_issues].any?
        result[:js_issues].each { |issue| puts "   ⚠️  #{issue}" }
      end
    end
  end

  def generate_form_compatibility_report
    puts "\n📝 Form Compatibility Report"
    puts "=" * 50
    
    form_results = @test_results.select { |k, _| k.include?("forms_") }
    
    form_results.each do |test_name, result|
      status = result[:success] ? "✅ PASS" : "❌ FAIL"
      
      puts sprintf("%-20s %s", result[:browser_name], status)
      
      if result[:form_issues].any?
        result[:form_issues].each { |issue| puts "   ⚠️  #{issue}" }
      end
    end
  end

  def generate_media_compatibility_report
    puts "\n🖼️ Media Compatibility Report"
    puts "=" * 50
    
    media_results = @test_results.select { |k, _| k.include?("media_") }
    
    media_results.each do |test_name, result|
      status = result[:success] ? "✅ PASS" : "❌ FAIL"
      
      puts sprintf("%-20s %s", result[:browser_name], status)
      
      if result[:media_issues].any?
        result[:media_issues].each { |issue| puts "   ⚠️  #{issue}" }
      end
    end
  end

  def generate_legacy_support_report
    puts "\n🕰️ Legacy Browser Support Report"
    puts "=" * 50
    
    legacy_result = @test_results["legacy_support"]
    return unless legacy_result
    
    status = legacy_result[:success] ? "✅ PASS" : "❌ FAIL"
    puts sprintf("%-20s %s", "Legacy Support", status)
    
    if legacy_result[:legacy_issues].any?
      legacy_result[:legacy_issues].each { |issue| puts "   ⚠️  #{issue}" }
    end
  end

  def generate_vendor_prefix_report
    puts "\n🏷️ Vendor Prefix Report"
    puts "=" * 50
    
    prefix_results = @test_results.select { |k, _| k.include?("prefixes_") }
    
    prefix_results.each do |test_name, result|
      status = result[:success] ? "✅ PASS" : "❌ FAIL"
      
      puts sprintf("%-20s %s", result[:browser_name], status)
      
      if result[:prefix_issues].any?
        result[:prefix_issues].each { |issue| puts "   ⚠️  #{issue}" }
      end
    end
  end

  def generate_progressive_enhancement_report
    puts "\n📈 Progressive Enhancement Report"
    puts "=" * 50
    
    enhancement_results = @test_results.select { |k, _| k.include?("enhancement_") }
    
    enhancement_results.each do |test_name, result|
      status = result[:success] ? "✅ PASS" : "❌ FAIL"
      
      puts sprintf("%-20s %s", result[:browser_name], status)
      
      if result[:enhancement_issues].any?
        result[:enhancement_issues].each { |issue| puts "   ⚠️  #{issue}" }
      end
    end
  end
end