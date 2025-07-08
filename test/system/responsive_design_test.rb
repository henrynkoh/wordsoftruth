# frozen_string_literal: true

require "application_system_test_case"

class ResponsiveDesignTest < ApplicationSystemTestCase
  # Breakpoint configurations based on common CSS frameworks
  BREAKPOINTS = {
    xs: { name: "Extra Small", width: 320, height: 568 },    # Small phones
    sm: { name: "Small", width: 576, height: 768 },         # Large phones
    md: { name: "Medium", width: 768, height: 1024 },       # Tablets
    lg: { name: "Large", width: 992, height: 768 },         # Small laptops
    xl: { name: "Extra Large", width: 1200, height: 800 },  # Desktop
    xxl: { name: "XXL", width: 1400, height: 900 }          # Large desktop
  }.freeze

  # Common responsive design patterns to test
  RESPONSIVE_PATTERNS = [
    :navigation_collapse,
    :sidebar_hide,
    :grid_stack,
    :text_scaling,
    :button_sizing,
    :image_scaling,
    :table_responsiveness,
    :form_adaptation
  ].freeze

  def setup
    super
    @test_results = {}
    @user = create_test_user
    sign_in_test_user
  end

  test "navigation responsiveness across breakpoints" do
    BREAKPOINTS.each do |breakpoint_key, config|
      test_navigation_at_breakpoint(breakpoint_key, config)
    end

    generate_navigation_responsiveness_report
  end

  test "content layout adaptation" do
    BREAKPOINTS.each do |breakpoint_key, config|
      test_content_layout_at_breakpoint(breakpoint_key, config)
    end

    generate_layout_adaptation_report
  end

  test "form responsiveness" do
    BREAKPOINTS.each do |breakpoint_key, config|
      test_form_responsiveness_at_breakpoint(breakpoint_key, config)
    end

    generate_form_responsiveness_report
  end

  test "table and data display responsiveness" do
    BREAKPOINTS.each do |breakpoint_key, config|
      test_table_responsiveness_at_breakpoint(breakpoint_key, config)
    end

    generate_table_responsiveness_report
  end

  test "image and media responsiveness" do
    BREAKPOINTS.each do |breakpoint_key, config|
      test_media_responsiveness_at_breakpoint(breakpoint_key, config)
    end

    generate_media_responsiveness_report
  end

  test "typography scaling" do
    BREAKPOINTS.each do |breakpoint_key, config|
      test_typography_at_breakpoint(breakpoint_key, config)
    end

    generate_typography_report
  end

  test "grid system behavior" do
    BREAKPOINTS.each do |breakpoint_key, config|
      test_grid_system_at_breakpoint(breakpoint_key, config)
    end

    generate_grid_system_report
  end

  test "touch target sizing across devices" do
    BREAKPOINTS.select { |k, v| v[:width] <= 768 }.each do |breakpoint_key, config|
      test_touch_targets_at_breakpoint(breakpoint_key, config)
    end

    generate_touch_target_report
  end

  private

  def test_navigation_at_breakpoint(breakpoint_key, config)
    puts "🧭 Testing navigation at #{config[:name]} (#{config[:width]}px)"
    
    start_time = Time.current
    issues = []
    
    begin
      resize_to_breakpoint(config)
      visit root_path
      
      # Test navigation visibility and behavior
      if config[:width] <= 768
        # Mobile/tablet: should have collapsible navigation
        if has_selector?(".navbar-toggler, .menu-toggle, .hamburger")
          # Good: has mobile menu toggle
          toggle_button = find(".navbar-toggler, .menu-toggle, .hamburger", match: :first)
          
          # Test toggle functionality
          toggle_button.click
          
          # Navigation menu should appear
          if has_selector?(".navbar-collapse.show, .mobile-menu.open", visible: true)
            # Good: mobile menu opens
          else
            issues << "Mobile menu toggle doesn't show navigation"
          end
          
          # Test closing mobile menu
          toggle_button.click
          if has_no_selector?(".navbar-collapse.show, .mobile-menu.open", visible: true)
            # Good: mobile menu closes
          else
            issues << "Mobile menu doesn't close properly"
          end
          
        else
          issues << "No mobile navigation toggle found at #{config[:width]}px"
        end
        
        # Check that full navigation is hidden
        if has_selector?(".navbar-nav", visible: true) && !has_selector?(".navbar-collapse.show")
          desktop_nav_visible = page.evaluate_script(<<~JS)
            const nav = document.querySelector('.navbar-nav');
            if (!nav) return false;
            const styles = window.getComputedStyle(nav);
            return styles.display !== 'none' && styles.visibility !== 'hidden';
          JS
          
          if desktop_nav_visible
            issues << "Desktop navigation visible on mobile at #{config[:width]}px"
          end
        end
        
      else
        # Desktop: should have full navigation visible
        if has_selector?(".navbar-nav", visible: true)
          # Good: desktop navigation visible
        else
          issues << "Desktop navigation not visible at #{config[:width]}px"
        end
        
        # Mobile toggle should be hidden
        if has_selector?(".navbar-toggler, .menu-toggle", visible: true)
          issues << "Mobile toggle visible on desktop at #{config[:width]}px"
        end
      end
      
      # Test navigation links accessibility
      nav_links = all("nav a, .navbar a")
      nav_links.each do |link|
        link_size = link.native.size
        if config[:width] <= 768 && (link_size.width < 44 || link_size.height < 44)
          issues << "Navigation link too small for touch: #{link_size.width}x#{link_size.height}px"
        end
      end
      
    rescue => e
      issues << "Exception: #{e.message}"
    end
    
    duration = Time.current - start_time
    
    @test_results["navigation_#{breakpoint_key}"] = {
      breakpoint: breakpoint_key,
      config: config,
      issues: issues,
      success: issues.empty?,
      duration: duration,
      test_type: "navigation"
    }
  end

  def test_content_layout_at_breakpoint(breakpoint_key, config)
    puts "📐 Testing content layout at #{config[:name]} (#{config[:width]}px)"
    
    start_time = Time.current
    issues = []
    
    begin
      resize_to_breakpoint(config)
      visit text_notes_path
      
      # Test main content area responsiveness
      check_horizontal_scrolling(issues, config)
      check_content_overflow(issues, config)
      check_sidebar_behavior(issues, config)
      check_grid_adaptation(issues, config)
      
      # Test specific pages
      visit new_text_note_path
      check_form_layout(issues, config)
      
    rescue => e
      issues << "Exception: #{e.message}"
    end
    
    duration = Time.current - start_time
    
    @test_results["layout_#{breakpoint_key}"] = {
      breakpoint: breakpoint_key,
      config: config,
      issues: issues,
      success: issues.empty?,
      duration: duration,
      test_type: "layout"
    }
  end

  def test_form_responsiveness_at_breakpoint(breakpoint_key, config)
    puts "📝 Testing form responsiveness at #{config[:name]} (#{config[:width]}px)"
    
    start_time = Time.current
    issues = []
    
    begin
      resize_to_breakpoint(config)
      visit new_text_note_path
      
      # Test form field widths
      form_fields = all("input, textarea, select")
      form_fields.each do |field|
        field_width = field.native.size.width
        container_width = config[:width]
        
        # Form fields should not be wider than their container
        if field_width > container_width
          issues << "Form field wider than container: #{field_width}px > #{container_width}px"
        end
        
        # Form fields should have appropriate width for screen size
        width_percentage = (field_width.to_f / container_width) * 100
        
        if config[:width] <= 576 # Mobile
          if width_percentage < 80
            issues << "Form field too narrow on mobile: #{width_percentage.round}% width"
          end
        elsif config[:width] <= 768 # Tablet
          if width_percentage > 90
            issues << "Form field too wide on tablet: #{width_percentage.round}% width"
          end
        else # Desktop
          if width_percentage > 60
            issues << "Form field too wide on desktop: #{width_percentage.round}% width"
          end
        end
      end
      
      # Test form button sizing
      form_buttons = all("button, input[type='submit']")
      form_buttons.each do |button|
        button_size = button.native.size
        
        if config[:width] <= 768 # Touch devices
          if button_size.width < 44 || button_size.height < 44
            issues << "Form button too small for touch: #{button_size.width}x#{button_size.height}px"
          end
        end
      end
      
      # Test form layout adaptation
      if config[:width] <= 576
        # On mobile, form should stack vertically
        form_layout = page.evaluate_script(<<~JS)
          const form = document.querySelector('form');
          if (!form) return 'no-form';
          
          const formGroups = form.querySelectorAll('.form-group, .field');
          let stackedProperly = true;
          
          for (let i = 0; i < formGroups.length - 1; i++) {
            const current = formGroups[i].getBoundingClientRect();
            const next = formGroups[i + 1].getBoundingClientRect();
            
            if (current.bottom > next.top) {
              stackedProperly = false;
              break;
            }
          }
          
          return stackedProperly ? 'stacked' : 'overlapping';
        JS
        
        if form_layout == 'overlapping'
          issues << "Form elements overlapping on mobile"
        end
      end
      
    rescue => e
      issues << "Exception: #{e.message}"
    end
    
    duration = Time.current - start_time
    
    @test_results["forms_#{breakpoint_key}"] = {
      breakpoint: breakpoint_key,
      config: config,
      issues: issues,
      success: issues.empty?,
      duration: duration,
      test_type: "forms"
    }
  end

  def test_table_responsiveness_at_breakpoint(breakpoint_key, config)
    puts "📊 Testing table responsiveness at #{config[:name]} (#{config[:width]}px)"
    
    start_time = Time.current
    issues = []
    
    begin
      resize_to_breakpoint(config)
      visit text_notes_path
      
      # Look for tables
      tables = all("table")
      
      tables.each_with_index do |table, index|
        table_width = table.native.size.width
        viewport_width = config[:width]
        
        if table_width > viewport_width
          # Table is wider than viewport
          if config[:width] <= 768
            # On small screens, table should be responsive
            table_responsive = has_selector?(".table-responsive") ||
                              page.evaluate_script(<<~JS)
                                const table = arguments[0];
                                const container = table.closest('.table-responsive, .table-container');
                                if (container) {
                                  const styles = window.getComputedStyle(container);
                                  return styles.overflowX === 'auto' || styles.overflowX === 'scroll';
                                }
                                return false;
                              JS, table.native)
            
            if !table_responsive
              issues << "Table #{index + 1} not responsive - wider than viewport with no horizontal scroll"
            end
          else
            issues << "Table #{index + 1} wider than viewport on desktop: #{table_width}px > #{viewport_width}px"
          end
        end
        
        # Check table cell content overflow
        cells = table.all("td, th")
        cells.each_with_index do |cell, cell_index|
          cell_overflow = page.evaluate_script(<<~JS)
            const cell = arguments[0];
            return cell.scrollWidth > cell.clientWidth;
          JS, cell.native)
          
          if cell_overflow && config[:width] <= 768
            issues << "Table cell #{cell_index + 1} content overflowing on mobile"
          end
        end
      end
      
    rescue => e
      issues << "Exception: #{e.message}"
    end
    
    duration = Time.current - start_time
    
    @test_results["tables_#{breakpoint_key}"] = {
      breakpoint: breakpoint_key,
      config: config,
      issues: issues,
      success: issues.empty?,
      duration: duration,
      test_type: "tables"
    }
  end

  def test_media_responsiveness_at_breakpoint(breakpoint_key, config)
    puts "🖼️ Testing media responsiveness at #{config[:name]} (#{config[:width]}px)"
    
    start_time = Time.current
    issues = []
    
    begin
      resize_to_breakpoint(config)
      visit root_path
      
      # Test images
      images = all("img")
      images.each_with_index do |img, index|
        img_width = img.native.size.width
        viewport_width = config[:width]
        
        # Images should not overflow their containers
        if img_width > viewport_width
          issues << "Image #{index + 1} wider than viewport: #{img_width}px > #{viewport_width}px"
        end
        
        # Check for responsive image attributes
        img_responsive = img["class"]&.include?("responsive") ||
                        img["style"]&.include?("max-width") ||
                        page.evaluate_script(<<~JS)
                          const img = arguments[0];
                          const styles = window.getComputedStyle(img);
                          return styles.maxWidth === '100%' || styles.width === '100%';
                        JS, img.native)
        
        if !img_responsive && img_width > 300
          issues << "Image #{index + 1} may not be responsive (no responsive classes/styles)"
        end
      end
      
      # Test video elements
      videos = all("video")
      videos.each_with_index do |video, index|
        video_width = video.native.size.width
        viewport_width = config[:width]
        
        if video_width > viewport_width
          issues << "Video #{index + 1} wider than viewport: #{video_width}px > #{viewport_width}px"
        end
      end
      
    rescue => e
      issues << "Exception: #{e.message}"
    end
    
    duration = Time.current - start_time
    
    @test_results["media_#{breakpoint_key}"] = {
      breakpoint: breakpoint_key,
      config: config,
      issues: issues,
      success: issues.empty?,
      duration: duration,
      test_type: "media"
    }
  end

  def test_typography_at_breakpoint(breakpoint_key, config)
    puts "📝 Testing typography at #{config[:name]} (#{config[:width]}px)"
    
    start_time = Time.current
    issues = []
    
    begin
      resize_to_breakpoint(config)
      visit root_path
      
      # Test heading sizes
      headings = all("h1, h2, h3, h4, h5, h6")
      headings.each do |heading|
        font_size = page.evaluate_script(<<~JS)
          const heading = arguments[0];
          return parseInt(window.getComputedStyle(heading).fontSize);
        JS, heading.native)
        
        tag_name = heading.tag_name.downcase
        
        # Define minimum font sizes for different screen sizes
        min_size = if config[:width] <= 576 # Mobile
          case tag_name
          when "h1" then 24
          when "h2" then 20
          when "h3" then 18
          when "h4" then 16
          when "h5" then 14
          when "h6" then 14
          end
        else # Desktop
          case tag_name
          when "h1" then 32
          when "h2" then 24
          when "h3" then 20
          when "h4" then 18
          when "h5" then 16
          when "h6" then 14
          end
        end
        
        if font_size < min_size
          issues << "#{tag_name.upcase} too small at #{config[:width]}px: #{font_size}px < #{min_size}px"
        end
      end
      
      # Test body text size
      body_text_elements = all("p, div, span").select do |el|
        # Filter for elements that contain actual text content
        el.text.strip.length > 10
      end
      
      body_text_elements.first(5).each do |element| # Test first 5 to avoid too many checks
        font_size = page.evaluate_script(<<~JS)
          const element = arguments[0];
          return parseInt(window.getComputedStyle(element).fontSize);
        JS, element.native)
        
        min_body_size = config[:width] <= 576 ? 14 : 16
        
        if font_size < min_body_size
          issues << "Body text too small at #{config[:width]}px: #{font_size}px < #{min_body_size}px"
        end
      end
      
      # Test line height
      text_elements = all("p, div").select { |el| el.text.strip.length > 50 }
      text_elements.first(3).each do |element|
        line_height = page.evaluate_script(<<~JS)
          const element = arguments[0];
          const styles = window.getComputedStyle(element);
          const fontSize = parseFloat(styles.fontSize);
          const lineHeight = parseFloat(styles.lineHeight);
          return lineHeight / fontSize;
        JS, element.native)
        
        if line_height < 1.2
          issues << "Line height too small (#{line_height.round(2)}) - should be at least 1.2"
        end
      end
      
    rescue => e
      issues << "Exception: #{e.message}"
    end
    
    duration = Time.current - start_time
    
    @test_results["typography_#{breakpoint_key}"] = {
      breakpoint: breakpoint_key,
      config: config,
      issues: issues,
      success: issues.empty?,
      duration: duration,
      test_type: "typography"
    }
  end

  def test_grid_system_at_breakpoint(breakpoint_key, config)
    puts "📏 Testing grid system at #{config[:name]} (#{config[:width]}px)"
    
    start_time = Time.current
    issues = []
    
    begin
      resize_to_breakpoint(config)
      visit text_notes_path
      
      # Look for grid containers
      grid_containers = all(".row, .grid, .flex-container, [class*='grid-']")
      
      grid_containers.each_with_index do |container, index|
        # Check if grid items stack properly on small screens
        grid_items = container.all(".col, .grid-item, .flex-item, [class*='col-']")
        
        if grid_items.length > 1 && config[:width] <= 768
          # On mobile/tablet, check if items stack vertically
          items_stacked = page.evaluate_script(<<~JS)
            const items = arguments[0];
            let stacked = true;
            
            for (let i = 0; i < items.length - 1; i++) {
              const current = items[i].getBoundingClientRect();
              const next = items[i + 1].getBoundingClientRect();
              
              // If items are side by side instead of stacked
              if (current.right < next.left || next.right < current.left) {
                // Check if there's enough space for both items
                const totalWidth = current.width + next.width;
                if (totalWidth > window.innerWidth * 0.9) {
                  stacked = false;
                  break;
                }
              }
            }
            
            return stacked;
          JS, grid_items.map(&:native))
          
          if !items_stacked
            issues << "Grid container #{index + 1} items don't stack properly on mobile"
          end
        end
        
        # Check for horizontal overflow
        container_overflow = page.evaluate_script(<<~JS)
          const container = arguments[0];
          return container.scrollWidth > container.clientWidth;
        JS, container.native)
        
        if container_overflow
          issues << "Grid container #{index + 1} has horizontal overflow"
        end
      end
      
    rescue => e
      issues << "Exception: #{e.message}"
    end
    
    duration = Time.current - start_time
    
    @test_results["grid_#{breakpoint_key}"] = {
      breakpoint: breakpoint_key,
      config: config,
      issues: issues,
      success: issues.empty?,
      duration: duration,
      test_type: "grid"
    }
  end

  def test_touch_targets_at_breakpoint(breakpoint_key, config)
    puts "👆 Testing touch targets at #{config[:name]} (#{config[:width]}px)"
    
    start_time = Time.current
    issues = []
    
    begin
      resize_to_breakpoint(config)
      visit text_notes_path
      
      # Test interactive elements
      interactive_elements = all("button, a, input[type='submit'], input[type='button'], input[type='checkbox'], input[type='radio']")
      
      interactive_elements.each_with_index do |element, index|
        element_size = element.native.size
        
        # Minimum touch target size is 44px x 44px
        if element_size.width < 44 || element_size.height < 44
          issues << "Touch target #{index + 1} too small: #{element_size.width}x#{element_size.height}px (min 44x44px)"
        end
        
        # Check spacing between touch targets
        nearby_elements = page.evaluate_script(<<~JS)
          const element = arguments[0];
          const rect = element.getBoundingClientRect();
          const allInteractive = document.querySelectorAll('button, a, input[type="submit"], input[type="button"]');
          
          let tooClose = 0;
          allInteractive.forEach(other => {
            if (other === element) return;
            
            const otherRect = other.getBoundingClientRect();
            const distance = Math.sqrt(
              Math.pow(rect.left - otherRect.left, 2) + 
              Math.pow(rect.top - otherRect.top, 2)
            );
            
            if (distance < 44) {
              tooClose++;
            }
          });
          
          return tooClose;
        JS, element.native)
        
        if nearby_elements > 0
          issues << "Touch target #{index + 1} has #{nearby_elements} targets too close (< 44px spacing)"
        end
      end
      
    rescue => e
      issues << "Exception: #{e.message}"
    end
    
    duration = Time.current - start_time
    
    @test_results["touch_#{breakpoint_key}"] = {
      breakpoint: breakpoint_key,
      config: config,
      issues: issues,
      success: issues.empty?,
      duration: duration,
      test_type: "touch_targets"
    }
  end

  # Helper methods for common responsive design checks

  def check_horizontal_scrolling(issues, config)
    has_horizontal_scroll = page.evaluate_script("document.body.scrollWidth > window.innerWidth")
    if has_horizontal_scroll
      issues << "Horizontal scrolling detected at #{config[:width]}px"
    end
  end

  def check_content_overflow(issues, config)
    overflowing_elements = page.evaluate_script(<<~JS)
      let overflowCount = 0;
      document.querySelectorAll('*').forEach(el => {
        if (el.scrollWidth > el.clientWidth && 
            window.getComputedStyle(el).overflow === 'visible') {
          overflowCount++;
        }
      });
      return overflowCount;
    JS)
    
    if overflowing_elements > 0
      issues << "#{overflowing_elements} elements have content overflow"
    end
  end

  def check_sidebar_behavior(issues, config)
    sidebar = first(".sidebar, .side-nav, aside")
    return unless sidebar
    
    if config[:width] <= 768
      # On mobile/tablet, sidebar should be hidden or collapsed
      sidebar_visible = page.evaluate_script(<<~JS)
        const sidebar = arguments[0];
        const styles = window.getComputedStyle(sidebar);
        return styles.display !== 'none' && styles.visibility !== 'hidden';
      JS, sidebar.native)
      
      if sidebar_visible
        # Check if it's properly positioned (off-screen or overlay)
        sidebar_position = page.evaluate_script(<<~JS)
          const sidebar = arguments[0];
          const rect = sidebar.getBoundingClientRect();
          return {
            left: rect.left,
            width: rect.width,
            position: window.getComputedStyle(sidebar).position
          };
        JS, sidebar.native)
        
        if sidebar_position["left"] >= 0 && sidebar_position["position"] != "fixed"
          issues << "Sidebar visible and not properly positioned on mobile"
        end
      end
    else
      # On desktop, sidebar should be visible
      sidebar_visible = page.evaluate_script(<<~JS)
        const sidebar = arguments[0];
        const styles = window.getComputedStyle(sidebar);
        return styles.display !== 'none' && styles.visibility !== 'hidden';
      JS, sidebar.native)
      
      if !sidebar_visible
        issues << "Sidebar hidden on desktop"
      end
    end
  end

  def check_grid_adaptation(issues, config)
    grid_containers = all(".row, .grid, [class*='grid-']")
    
    grid_containers.each_with_index do |container, index|
      container_width = container.native.size.width
      
      if container_width > config[:width]
        issues << "Grid container #{index + 1} wider than viewport"
      end
    end
  end

  def check_form_layout(issues, config)
    form = first("form")
    return unless form
    
    form_width = form.native.size.width
    
    if config[:width] <= 576 # Mobile
      form_width_percentage = (form_width.to_f / config[:width]) * 100
      if form_width_percentage < 90
        issues << "Form too narrow on mobile: #{form_width_percentage.round}% width"
      end
    end
  end

  def resize_to_breakpoint(config)
    page.driver.browser.manage.window.resize_to(config[:width], config[:height])
    sleep 0.5 # Allow time for CSS transitions
  end

  def create_test_user
    User.create!(
      email: "responsive.test@example.com",
      name: "Responsive Test User",
      provider: "google_oauth2",
      uid: "responsive123"
    )
  end

  def sign_in_test_user
    page.execute_script(<<~JS)
      sessionStorage.setItem('test_user_signed_in', 'true');
    JS
    
    visit root_path
  end

  # Report generation methods

  def generate_navigation_responsiveness_report
    puts "\n🧭 Navigation Responsiveness Report"
    puts "=" * 60
    
    nav_results = @test_results.select { |k, _| k.include?("navigation_") }
    
    nav_results.each do |test_name, result|
      status = result[:success] ? "✅ PASS" : "❌ FAIL"
      config = result[:config]
      
      puts sprintf("%-15s %-12s %s", 
        config[:name], "#{config[:width]}px", status)
      
      if result[:issues].any?
        result[:issues].each { |issue| puts "   ⚠️  #{issue}" }
      end
    end
  end

  def generate_layout_adaptation_report
    puts "\n📐 Layout Adaptation Report"
    puts "=" * 60
    
    layout_results = @test_results.select { |k, _| k.include?("layout_") }
    
    layout_results.each do |test_name, result|
      status = result[:success] ? "✅ PASS" : "❌ FAIL"
      config = result[:config]
      
      puts sprintf("%-15s %-12s %s", 
        config[:name], "#{config[:width]}px", status)
      
      if result[:issues].any?
        result[:issues].each { |issue| puts "   ⚠️  #{issue}" }
      end
    end
  end

  def generate_form_responsiveness_report
    puts "\n📝 Form Responsiveness Report"
    puts "=" * 60
    
    form_results = @test_results.select { |k, _| k.include?("forms_") }
    
    form_results.each do |test_name, result|
      status = result[:success] ? "✅ PASS" : "❌ FAIL"
      config = result[:config]
      
      puts sprintf("%-15s %-12s %s", 
        config[:name], "#{config[:width]}px", status)
      
      if result[:issues].any?
        result[:issues].each { |issue| puts "   ⚠️  #{issue}" }
      end
    end
  end

  def generate_table_responsiveness_report
    puts "\n📊 Table Responsiveness Report"
    puts "=" * 60
    
    table_results = @test_results.select { |k, _| k.include?("tables_") }
    
    table_results.each do |test_name, result|
      status = result[:success] ? "✅ PASS" : "❌ FAIL"
      config = result[:config]
      
      puts sprintf("%-15s %-12s %s", 
        config[:name], "#{config[:width]}px", status)
      
      if result[:issues].any?
        result[:issues].each { |issue| puts "   ⚠️  #{issue}" }
      end
    end
  end

  def generate_media_responsiveness_report
    puts "\n🖼️ Media Responsiveness Report"
    puts "=" * 60
    
    media_results = @test_results.select { |k, _| k.include?("media_") }
    
    media_results.each do |test_name, result|
      status = result[:success] ? "✅ PASS" : "❌ FAIL"
      config = result[:config]
      
      puts sprintf("%-15s %-12s %s", 
        config[:name], "#{config[:width]}px", status)
      
      if result[:issues].any?
        result[:issues].each { |issue| puts "   ⚠️  #{issue}" }
      end
    end
  end

  def generate_typography_report
    puts "\n📝 Typography Report"
    puts "=" * 60
    
    typography_results = @test_results.select { |k, _| k.include?("typography_") }
    
    typography_results.each do |test_name, result|
      status = result[:success] ? "✅ PASS" : "❌ FAIL"
      config = result[:config]
      
      puts sprintf("%-15s %-12s %s", 
        config[:name], "#{config[:width]}px", status)
      
      if result[:issues].any?
        result[:issues].each { |issue| puts "   ⚠️  #{issue}" }
      end
    end
  end

  def generate_grid_system_report
    puts "\n📏 Grid System Report"
    puts "=" * 60
    
    grid_results = @test_results.select { |k, _| k.include?("grid_") }
    
    grid_results.each do |test_name, result|
      status = result[:success] ? "✅ PASS" : "❌ FAIL"
      config = result[:config]
      
      puts sprintf("%-15s %-12s %s", 
        config[:name], "#{config[:width]}px", status)
      
      if result[:issues].any?
        result[:issues].each { |issue| puts "   ⚠️  #{issue}" }
      end
    end
  end

  def generate_touch_target_report
    puts "\n👆 Touch Target Report"
    puts "=" * 60
    
    touch_results = @test_results.select { |k, _| k.include?("touch_") }
    
    touch_results.each do |test_name, result|
      status = result[:success] ? "✅ PASS" : "❌ FAIL"
      config = result[:config]
      
      puts sprintf("%-15s %-12s %s", 
        config[:name], "#{config[:width]}px", status)
      
      if result[:issues].any?
        result[:issues].each { |issue| puts "   ⚠️  #{issue}" }
      end
    end
  end
end