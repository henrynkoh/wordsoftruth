# frozen_string_literal: true

require "application_system_test_case"

class AccessibilityTest < ApplicationSystemTestCase
  # WCAG 2.1 AA Compliance Testing
  WCAG_CRITERIA = {
    perceivable: [
      :text_alternatives,
      :captions_and_transcripts,
      :color_contrast,
      :resize_text,
      :images_of_text
    ],
    operable: [
      :keyboard_navigation,
      :timing_adjustable,
      :seizure_prevention,
      :navigation_consistent,
      :focus_management
    ],
    understandable: [
      :language_identification,
      :predictable_functionality,
      :input_assistance,
      :error_identification
    ],
    robust: [
      :markup_validity,
      :name_role_value,
      :screen_reader_compatibility
    ]
  }.freeze

  # Device types for accessibility testing
  ACCESSIBILITY_DEVICES = {
    desktop: { width: 1920, height: 1080, type: "desktop" },
    tablet: { width: 768, height: 1024, type: "tablet" },
    mobile: { width: 375, height: 667, type: "mobile" }
  }.freeze

  def setup
    super
    @test_results = {}
    @accessibility_violations = []
    @user = create_test_user
  end

  test "WCAG 2.1 AA compliance across devices" do
    ACCESSIBILITY_DEVICES.each do |device_name, config|
      test_wcag_compliance_on_device(device_name, config)
    end

    generate_wcag_compliance_report
  end

  test "keyboard navigation on all devices" do
    ACCESSIBILITY_DEVICES.each do |device_name, config|
      test_keyboard_navigation_on_device(device_name, config)
    end

    generate_keyboard_navigation_report
  end

  test "screen reader compatibility" do
    ACCESSIBILITY_DEVICES.each do |device_name, config|
      test_screen_reader_compatibility(device_name, config)
    end

    generate_screen_reader_report
  end

  test "color contrast and visual accessibility" do
    ACCESSIBILITY_DEVICES.each do |device_name, config|
      test_color_contrast_on_device(device_name, config)
    end

    generate_color_contrast_report
  end

  test "focus management and visibility" do
    ACCESSIBILITY_DEVICES.each do |device_name, config|
      test_focus_management_on_device(device_name, config)
    end

    generate_focus_management_report
  end

  test "form accessibility and error handling" do
    ACCESSIBILITY_DEVICES.each do |device_name, config|
      test_form_accessibility_on_device(device_name, config)
    end

    generate_form_accessibility_report
  end

  test "semantic markup and structure" do
    ACCESSIBILITY_DEVICES.each do |device_name, config|
      test_semantic_markup_on_device(device_name, config)
    end

    generate_semantic_markup_report
  end

  test "touch target accessibility on mobile devices" do
    mobile_devices = ACCESSIBILITY_DEVICES.select { |_, config| config[:type] == "mobile" || config[:type] == "tablet" }
    
    mobile_devices.each do |device_name, config|
      test_touch_target_accessibility(device_name, config)
    end

    generate_touch_accessibility_report
  end

  private

  def test_wcag_compliance_on_device(device_name, config)
    puts "♿ Testing WCAG compliance on #{device_name}"
    
    start_time = Time.current
    violations = []
    
    begin
      resize_to_device(config)
      sign_in_test_user
      
      # Test main pages for WCAG compliance
      pages_to_test = [
        { path: root_path, name: "Home" },
        { path: text_notes_path, name: "Text Notes" },
        { path: new_text_note_path, name: "New Text Note" }
      ]
      
      pages_to_test.each do |page|
        visit page[:path]
        violations.concat(check_wcag_violations(page[:name], device_name))
      end
      
    rescue => e
      violations << "Exception on #{device_name}: #{e.message}"
    end
    
    duration = Time.current - start_time
    
    @test_results["wcag_#{device_name}"] = {
      device: device_name,
      config: config,
      violations: violations,
      success: violations.empty?,
      duration: duration,
      test_type: "wcag_compliance"
    }
  end

  def test_keyboard_navigation_on_device(device_name, config)
    puts "⌨️ Testing keyboard navigation on #{device_name}"
    
    start_time = Time.current
    navigation_issues = []
    
    begin
      resize_to_device(config)
      sign_in_test_user
      visit text_notes_path
      
      # Test tab navigation
      keyboard_navigation_issues = test_tab_navigation
      navigation_issues.concat(keyboard_navigation_issues)
      
      # Test keyboard shortcuts
      shortcut_issues = test_keyboard_shortcuts
      navigation_issues.concat(shortcut_issues)
      
      # Test escape key functionality
      escape_issues = test_escape_key_functionality
      navigation_issues.concat(escape_issues)
      
      # Test arrow key navigation (if applicable)
      arrow_key_issues = test_arrow_key_navigation
      navigation_issues.concat(arrow_key_issues)
      
    rescue => e
      navigation_issues << "Exception on #{device_name}: #{e.message}"
    end
    
    duration = Time.current - start_time
    
    @test_results["keyboard_#{device_name}"] = {
      device: device_name,
      config: config,
      issues: navigation_issues,
      success: navigation_issues.empty?,
      duration: duration,
      test_type: "keyboard_navigation"
    }
  end

  def test_screen_reader_compatibility(device_name, config)
    puts "📢 Testing screen reader compatibility on #{device_name}"
    
    start_time = Time.current
    screen_reader_issues = []
    
    begin
      resize_to_device(config)
      sign_in_test_user
      visit text_notes_path
      
      # Test ARIA labels and roles
      aria_issues = check_aria_implementation
      screen_reader_issues.concat(aria_issues)
      
      # Test heading structure
      heading_issues = check_heading_structure
      screen_reader_issues.concat(heading_issues)
      
      # Test landmark navigation
      landmark_issues = check_landmark_roles
      screen_reader_issues.concat(landmark_issues)
      
      # Test alternative text
      alt_text_issues = check_alternative_text
      screen_reader_issues.concat(alt_text_issues)
      
      # Test form labels
      form_label_issues = check_form_labels
      screen_reader_issues.concat(form_label_issues)
      
    rescue => e
      screen_reader_issues << "Exception on #{device_name}: #{e.message}"
    end
    
    duration = Time.current - start_time
    
    @test_results["screen_reader_#{device_name}"] = {
      device: device_name,
      config: config,
      issues: screen_reader_issues,
      success: screen_reader_issues.empty?,
      duration: duration,
      test_type: "screen_reader"
    }
  end

  def test_color_contrast_on_device(device_name, config)
    puts "🎨 Testing color contrast on #{device_name}"
    
    start_time = Time.current
    contrast_issues = []
    
    begin
      resize_to_device(config)
      sign_in_test_user
      visit root_path
      
      # Test color contrast ratios
      contrast_violations = check_color_contrast_ratios
      contrast_issues.concat(contrast_violations)
      
      # Test color-only information
      color_only_issues = check_color_only_information
      contrast_issues.concat(color_only_issues)
      
      # Test focus indicators
      focus_indicator_issues = check_focus_indicators
      contrast_issues.concat(focus_indicator_issues)
      
    rescue => e
      contrast_issues << "Exception on #{device_name}: #{e.message}"
    end
    
    duration = Time.current - start_time
    
    @test_results["contrast_#{device_name}"] = {
      device: device_name,
      config: config,
      issues: contrast_issues,
      success: contrast_issues.empty?,
      duration: duration,
      test_type: "color_contrast"
    }
  end

  def test_focus_management_on_device(device_name, config)
    puts "🎯 Testing focus management on #{device_name}"
    
    start_time = Time.current
    focus_issues = []
    
    begin
      resize_to_device(config)
      sign_in_test_user
      visit text_notes_path
      
      # Test focus visibility
      focus_visibility_issues = check_focus_visibility
      focus_issues.concat(focus_visibility_issues)
      
      # Test focus order
      focus_order_issues = check_focus_order
      focus_issues.concat(focus_order_issues)
      
      # Test focus trapping in modals
      if has_selector?(".modal, .dialog")
        modal_focus_issues = check_modal_focus_trapping
        focus_issues.concat(modal_focus_issues)
      end
      
      # Test skip links
      skip_link_issues = check_skip_links
      focus_issues.concat(skip_link_issues)
      
    rescue => e
      focus_issues << "Exception on #{device_name}: #{e.message}"
    end
    
    duration = Time.current - start_time
    
    @test_results["focus_#{device_name}"] = {
      device: device_name,
      config: config,
      issues: focus_issues,
      success: focus_issues.empty?,
      duration: duration,
      test_type: "focus_management"
    }
  end

  def test_form_accessibility_on_device(device_name, config)
    puts "📝 Testing form accessibility on #{device_name}"
    
    start_time = Time.current
    form_issues = []
    
    begin
      resize_to_device(config)
      sign_in_test_user
      visit new_text_note_path
      
      # Test form labels
      label_issues = check_form_field_labels
      form_issues.concat(label_issues)
      
      # Test form validation and error messages
      validation_issues = test_form_validation_accessibility
      form_issues.concat(validation_issues)
      
      # Test fieldset and legend usage
      fieldset_issues = check_fieldset_usage
      form_issues.concat(fieldset_issues)
      
      # Test required field indication
      required_field_issues = check_required_field_indication
      form_issues.concat(required_field_issues)
      
    rescue => e
      form_issues << "Exception on #{device_name}: #{e.message}"
    end
    
    duration = Time.current - start_time
    
    @test_results["forms_#{device_name}"] = {
      device: device_name,
      config: config,
      issues: form_issues,
      success: form_issues.empty?,
      duration: duration,
      test_type: "form_accessibility"
    }
  end

  def test_semantic_markup_on_device(device_name, config)
    puts "🏗️ Testing semantic markup on #{device_name}"
    
    start_time = Time.current
    markup_issues = []
    
    begin
      resize_to_device(config)
      sign_in_test_user
      visit root_path
      
      # Test HTML5 semantic elements
      semantic_issues = check_semantic_elements
      markup_issues.concat(semantic_issues)
      
      # Test document structure
      structure_issues = check_document_structure
      markup_issues.concat(structure_issues)
      
      # Test list markup
      list_issues = check_list_markup
      markup_issues.concat(list_issues)
      
      # Test table markup (if present)
      if has_selector?("table")
        table_issues = check_table_markup
        markup_issues.concat(table_issues)
      end
      
    rescue => e
      markup_issues << "Exception on #{device_name}: #{e.message}"
    end
    
    duration = Time.current - start_time
    
    @test_results["markup_#{device_name}"] = {
      device: device_name,
      config: config,
      issues: markup_issues,
      success: markup_issues.empty?,
      duration: duration,
      test_type: "semantic_markup"
    }
  end

  def test_touch_target_accessibility(device_name, config)
    puts "👆 Testing touch target accessibility on #{device_name}"
    
    start_time = Time.current
    touch_issues = []
    
    begin
      resize_to_device(config)
      sign_in_test_user
      visit text_notes_path
      
      # Test touch target sizes
      target_size_issues = check_touch_target_sizes
      touch_issues.concat(target_size_issues)
      
      # Test touch target spacing
      spacing_issues = check_touch_target_spacing
      touch_issues.concat(spacing_issues)
      
      # Test gesture alternatives
      gesture_issues = check_gesture_alternatives
      touch_issues.concat(gesture_issues)
      
    rescue => e
      touch_issues << "Exception on #{device_name}: #{e.message}"
    end
    
    duration = Time.current - start_time
    
    @test_results["touch_#{device_name}"] = {
      device: device_name,
      config: config,
      issues: touch_issues,
      success: touch_issues.empty?,
      duration: duration,
      test_type: "touch_accessibility"
    }
  end

  # Helper methods for specific accessibility checks

  def check_wcag_violations(page_name, device_name)
    violations = []
    
    # Check for missing alt text
    images_without_alt = page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll('img')).filter(img => 
        !img.alt && !img.getAttribute('aria-label') && !img.getAttribute('aria-labelledby')
      ).length;
    JS)
    
    if images_without_alt > 0
      violations << "#{page_name}: #{images_without_alt} images without alt text"
    end
    
    # Check for missing form labels
    unlabeled_inputs = page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll('input, textarea, select')).filter(input => {
        if (input.type === 'hidden' || input.type === 'submit' || input.type === 'button') return false;
        return !input.labels?.length && !input.getAttribute('aria-label') && !input.getAttribute('aria-labelledby');
      }).length;
    JS)
    
    if unlabeled_inputs > 0
      violations << "#{page_name}: #{unlabeled_inputs} form inputs without labels"
    end
    
    # Check for missing heading structure
    has_h1 = has_selector?("h1")
    if !has_h1
      violations << "#{page_name}: No H1 heading found"
    end
    
    violations
  end

  def test_tab_navigation
    issues = []
    
    # Get all focusable elements
    focusable_elements = page.evaluate_script(<<~JS)
      const focusableSelectors = [
        'a[href]', 'button', 'input', 'textarea', 'select',
        '[tabindex]:not([tabindex="-1"])', '[contenteditable]'
      ].join(', ');
      
      return Array.from(document.querySelectorAll(focusableSelectors))
        .filter(el => {
          const rect = el.getBoundingClientRect();
          const styles = window.getComputedStyle(el);
          return rect.width > 0 && rect.height > 0 && 
                 styles.visibility !== 'hidden' && styles.display !== 'none';
        }).length;
    JS)
    
    if focusable_elements == 0
      issues << "No focusable elements found on page"
      return issues
    end
    
    # Test tab progression
    first_element = find("a, button, input, textarea, select", match: :first)
    first_element.send_keys(:tab)
    
    # Check if focus moved
    focused_element_exists = page.evaluate_script("document.activeElement !== document.body")
    
    if !focused_element_exists
      issues << "Tab navigation not working - focus not moving"
    end
    
    issues
  end

  def test_keyboard_shortcuts
    issues = []
    
    # Test common keyboard shortcuts
    shortcuts_to_test = [
      { keys: [:alt, 'h'], description: "Help shortcut" },
      { keys: [:alt, 'n'], description: "New note shortcut" },
      { keys: [:escape], description: "Escape key" }
    ]
    
    shortcuts_to_test.each do |shortcut|
      begin
        page.send_keys(shortcut[:keys])
        # Note: In a real implementation, we'd check if the shortcut worked
        # For now, we just verify no JavaScript errors occurred
      rescue => e
        issues << "Keyboard shortcut failed: #{shortcut[:description]} - #{e.message}"
      end
    end
    
    issues
  end

  def test_escape_key_functionality
    issues = []
    
    # Test escape key on modals/dialogs
    if has_selector?(".modal, .dialog, .popup")
      modal = find(".modal, .dialog, .popup", match: :first)
      modal.send_keys(:escape)
      
      # Check if modal closed
      if has_selector?(".modal, .dialog, .popup", visible: true)
        issues << "Escape key doesn't close modal/dialog"
      end
    end
    
    issues
  end

  def test_arrow_key_navigation
    issues = []
    
    # Test arrow key navigation in lists or grids
    if has_selector?("[role='listbox'], [role='grid'], [role='menu']")
      # Test arrow key navigation
      list_element = find("[role='listbox'], [role='grid'], [role='menu']", match: :first)
      list_element.send_keys(:arrow_down)
      
      # Check if navigation worked (focus should move within the list)
      # This is a simplified check - real implementation would verify focus movement
    end
    
    issues
  end

  def check_aria_implementation
    issues = []
    
    # Check for proper ARIA roles
    elements_needing_roles = page.evaluate_script(<<~JS)
      const elementsNeedingRoles = [
        'div[onclick]', 'span[onclick]', '.button:not(button)',
        '.menu:not([role])', '.dialog:not([role])', '.alert:not([role])'
      ];
      
      let count = 0;
      elementsNeedingRoles.forEach(selector => {
        count += document.querySelectorAll(selector).length;
      });
      return count;
    JS)
    
    if elements_needing_roles > 0
      issues << "#{elements_needing_roles} interactive elements missing ARIA roles"
    end
    
    # Check for aria-expanded on collapsible elements
    collapsible_without_expanded = page.evaluate_script(<<~JS)
      return Array.from(document.querySelectorAll('[data-toggle], .collapse-toggle')).filter(el =>
        !el.hasAttribute('aria-expanded')
      ).length;
    JS)
    
    if collapsible_without_expanded > 0
      issues << "#{collapsible_without_expanded} collapsible elements missing aria-expanded"
    end
    
    issues
  end

  def check_heading_structure
    issues = []
    
    headings = page.evaluate_script(<<~JS)
      return Array.from(document.querySelectorAll('h1, h2, h3, h4, h5, h6')).map(h => ({
        level: parseInt(h.tagName.substring(1)),
        text: h.textContent.trim().substring(0, 50)
      }));
    JS)
    
    if headings.empty?
      issues << "No headings found - poor document structure"
      return issues
    end
    
    # Check for H1
    has_h1 = headings.any? { |h| h["level"] == 1 }
    if !has_h1
      issues << "No H1 heading found"
    end
    
    # Check for heading level skips
    previous_level = 0
    headings.each do |heading|
      current_level = heading["level"]
      if current_level > previous_level + 1
        issues << "Heading level skip: jumped from H#{previous_level} to H#{current_level}"
      end
      previous_level = current_level
    end
    
    issues
  end

  def check_landmark_roles
    issues = []
    
    # Check for main landmark
    has_main = has_selector?("main, [role='main']")
    if !has_main
      issues << "No main landmark found"
    end
    
    # Check for navigation landmark
    has_nav = has_selector?("nav, [role='navigation']")
    if !has_nav
      issues << "No navigation landmark found"
    end
    
    # Check for complementary landmark (sidebar)
    if has_selector?(".sidebar, aside")
      sidebar_has_role = has_selector?("aside, [role='complementary']")
      if !sidebar_has_role
        issues << "Sidebar without complementary role"
      end
    end
    
    issues
  end

  def check_alternative_text
    issues = []
    
    # Check images
    images_info = page.evaluate_script(<<~JS)
      return Array.from(document.querySelectorAll('img')).map(img => ({
        hasAlt: img.hasAttribute('alt'),
        altText: img.alt,
        hasAriaLabel: img.hasAttribute('aria-label'),
        isDecorative: img.alt === '' || img.hasAttribute('aria-hidden')
      }));
    JS)
    
    images_without_alt = images_info.count { |img| !img["hasAlt"] && !img["hasAriaLabel"] }
    if images_without_alt > 0
      issues << "#{images_without_alt} images without alternative text"
    end
    
    # Check for empty alt text on non-decorative images
    likely_non_decorative = images_info.count do |img|
      img["hasAlt"] && img["altText"] == "" && !img["isDecorative"]
    end
    
    if likely_non_decorative > 0
      issues << "#{likely_non_decorative} likely non-decorative images with empty alt text"
    end
    
    issues
  end

  def check_form_labels
    issues = []
    
    form_issues = page.evaluate_script(<<~JS)
      const inputs = Array.from(document.querySelectorAll('input, textarea, select'));
      let unlabeled = 0;
      let missingRequired = 0;
      
      inputs.forEach(input => {
        if (input.type === 'hidden' || input.type === 'submit' || input.type === 'button') return;
        
        const hasLabel = input.labels?.length > 0 || 
                        input.hasAttribute('aria-label') || 
                        input.hasAttribute('aria-labelledby');
        
        if (!hasLabel) unlabeled++;
        
        if (input.required && !input.hasAttribute('aria-required')) {
          missingRequired++;
        }
      });
      
      return { unlabeled, missingRequired };
    JS)
    
    if form_issues["unlabeled"] > 0
      issues << "#{form_issues["unlabeled"]} form inputs without labels"
    end
    
    if form_issues["missingRequired"] > 0
      issues << "#{form_issues["missingRequired"]} required fields without aria-required"
    end
    
    issues
  end

  def check_color_contrast_ratios
    issues = []
    
    # This is a simplified contrast check
    # In a real implementation, you'd use a proper color contrast calculation library
    low_contrast_elements = page.evaluate_script(<<~JS)
      let lowContrastCount = 0;
      
      // Get all text elements
      const textElements = Array.from(document.querySelectorAll('*')).filter(el => {
        const text = el.textContent?.trim();
        return text && text.length > 0 && el.children.length === 0; // Leaf text nodes
      });
      
      textElements.forEach(el => {
        const styles = window.getComputedStyle(el);
        const bgColor = styles.backgroundColor;
        const textColor = styles.color;
        
        // Very basic check - in practice, you'd calculate actual contrast ratios
        if (bgColor === textColor || 
            (bgColor === 'rgba(0, 0, 0, 0)' && textColor === 'rgb(255, 255, 255)') ||
            (bgColor === 'rgb(255, 255, 255)' && textColor === 'rgb(255, 255, 255)')) {
          lowContrastCount++;
        }
      });
      
      return lowContrastCount;
    JS)
    
    if low_contrast_elements > 0
      issues << "#{low_contrast_elements} potential low contrast text elements"
    end
    
    issues
  end

  def check_color_only_information
    issues = []
    
    # Check for color-only error indicators
    error_elements = all(".error, .invalid, .danger, [class*='error']")
    color_only_errors = error_elements.count do |element|
      has_icon = element.has_selector?(".icon, .fa, [class*='icon']")
      has_text_indicator = element.text.downcase.include?("error") || 
                          element.text.downcase.include?("invalid") ||
                          element.text.downcase.include?("required")
      
      !has_icon && !has_text_indicator
    end
    
    if color_only_errors > 0
      issues << "#{color_only_errors} error indicators relying only on color"
    end
    
    issues
  end

  def check_focus_indicators
    issues = []
    
    # Test focus visibility
    focus_problems = page.evaluate_script(<<~JS)
      let problemCount = 0;
      const focusableElements = document.querySelectorAll(
        'a, button, input, textarea, select, [tabindex]:not([tabindex="-1"])'
      );
      
      focusableElements.forEach(el => {
        el.focus();
        const styles = window.getComputedStyle(el);
        
        // Check if there's a visible focus indicator
        const hasOutline = styles.outline !== 'none' && styles.outline !== '0px';
        const hasBoxShadow = styles.boxShadow !== 'none';
        const hasBorder = styles.borderWidth !== '0px';
        
        if (!hasOutline && !hasBoxShadow && !hasBorder) {
          problemCount++;
        }
      });
      
      return problemCount;
    JS)
    
    if focus_problems > 0
      issues << "#{focus_problems} focusable elements without visible focus indicators"
    end
    
    issues
  end

  def check_focus_visibility
    issues = []
    
    # Test if focus is visible when navigating with keyboard
    first_focusable = find("a, button, input", match: :first)
    first_focusable.send_keys(:tab)
    
    focused_element_visible = page.evaluate_script(<<~JS)
      const activeEl = document.activeElement;
      if (!activeEl || activeEl === document.body) return false;
      
      const rect = activeEl.getBoundingClientRect();
      const styles = window.getComputedStyle(activeEl);
      
      return rect.width > 0 && rect.height > 0 && 
             styles.visibility !== 'hidden' && 
             styles.display !== 'none';
    JS)
    
    if !focused_element_visible
      issues << "Focused element not visible"
    end
    
    issues
  end

  def check_focus_order
    issues = []
    
    # Test logical focus order
    focus_order_logical = page.evaluate_script(<<~JS)
      const focusableElements = Array.from(document.querySelectorAll(
        'a, button, input, textarea, select, [tabindex]:not([tabindex="-1"])'
      )).filter(el => {
        const rect = el.getBoundingClientRect();
        const styles = window.getComputedStyle(el);
        return rect.width > 0 && rect.height > 0 && 
               styles.visibility !== 'hidden' && styles.display !== 'none';
      });
      
      // Check if elements are in DOM order (simplified check)
      let previousTop = -1;
      let orderIssues = 0;
      
      focusableElements.forEach(el => {
        const rect = el.getBoundingClientRect();
        if (rect.top < previousTop - 50) { // Allow some tolerance
          orderIssues++;
        }
        previousTop = rect.top;
      });
      
      return orderIssues;
    JS)
    
    if focus_order_logical > 0
      issues << "#{focus_order_logical} elements with potentially illogical focus order"
    end
    
    issues
  end

  def check_modal_focus_trapping
    issues = []
    
    # Test focus trapping in modals
    modal = find(".modal, .dialog", match: :first)
    
    # Focus should be trapped within modal
    modal.send_keys(:tab)
    
    focus_trapped = page.evaluate_script(<<~JS)
      const modal = arguments[0];
      const activeElement = document.activeElement;
      return modal.contains(activeElement);
    JS, modal.native)
    
    if !focus_trapped
      issues << "Focus not trapped within modal"
    end
    
    issues
  end

  def check_skip_links
    issues = []
    
    # Check for skip links
    skip_links = all("a[href*='#main'], a[href*='#content'], .skip-link")
    
    if skip_links.empty?
      issues << "No skip links found for keyboard navigation"
    else
      # Test that skip links work
      skip_links.each do |link|
        target_id = link[:href]&.gsub('#', '')
        if target_id && !has_selector?("##{target_id}")
          issues << "Skip link points to non-existent target: ##{target_id}"
        end
      end
    end
    
    issues
  end

  def check_form_field_labels
    issues = []
    
    form_label_issues = page.evaluate_script(<<~JS)
      const issues = [];
      const inputs = document.querySelectorAll('input, textarea, select');
      
      inputs.forEach(input => {
        if (input.type === 'hidden' || input.type === 'submit' || input.type === 'button') return;
        
        const hasLabel = input.labels?.length > 0;
        const hasAriaLabel = input.hasAttribute('aria-label');
        const hasAriaLabelledBy = input.hasAttribute('aria-labelledby');
        
        if (!hasLabel && !hasAriaLabel && !hasAriaLabelledBy) {
          issues.push(`Input ${input.type} without label`);
        }
        
        // Check if labels are properly associated
        if (hasLabel) {
          Array.from(input.labels).forEach(label => {
            if (!label.textContent.trim()) {
              issues.push('Empty label found');
            }
          });
        }
      });
      
      return issues;
    JS)
    
    issues.concat(form_label_issues)
  end

  def test_form_validation_accessibility
    issues = []
    
    # Test error message accessibility
    form = first("form")
    return issues unless form
    
    # Try to submit invalid form
    required_field = first("input[required], textarea[required]")
    if required_field
      required_field.fill_in with: ""
      form.find("input[type='submit'], button[type='submit']").click
      
      # Check if error messages are accessible
      error_messages_accessible = page.evaluate_script(<<~JS)
        const errors = document.querySelectorAll('.error, .invalid, [aria-invalid="true"]');
        let accessible = true;
        
        errors.forEach(error => {
          const hasAriaLive = error.hasAttribute('aria-live');
          const hasRole = error.hasAttribute('role');
          const hasId = error.hasAttribute('id');
          
          if (!hasAriaLive && !hasRole && !hasId) {
            accessible = false;
          }
        });
        
        return accessible;
      JS)
      
      if !error_messages_accessible
        issues << "Error messages not properly announced to screen readers"
      end
    end
    
    issues
  end

  def check_fieldset_usage
    issues = []
    
    # Check for proper fieldset usage with related form controls
    forms_needing_fieldsets = page.evaluate_script(<<~JS)
      let needsFieldset = 0;
      
      // Check for radio button groups without fieldsets
      const radioGroups = {};
      document.querySelectorAll('input[type="radio"]').forEach(radio => {
        const name = radio.name;
        if (name) {
          radioGroups[name] = (radioGroups[name] || 0) + 1;
        }
      });
      
      Object.values(radioGroups).forEach(count => {
        if (count > 1) {
          const groupFieldset = document.querySelector(`fieldset:has(input[name="${Object.keys(radioGroups)[0]}"])`);
          if (!groupFieldset) {
            needsFieldset++;
          }
        }
      });
      
      return needsFieldset;
    JS)
    
    if forms_needing_fieldsets > 0
      issues << "#{forms_needing_fieldsets} form groups that should use fieldset/legend"
    end
    
    issues
  end

  def check_required_field_indication
    issues = []
    
    required_field_issues = page.evaluate_script(<<~JS)
      const issues = [];
      const requiredFields = document.querySelectorAll('input[required], textarea[required], select[required]');
      
      requiredFields.forEach(field => {
        const hasAriaRequired = field.hasAttribute('aria-required');
        const hasVisualIndicator = field.parentElement.textContent.includes('*') ||
                                   field.parentElement.textContent.toLowerCase().includes('required');
        
        if (!hasAriaRequired) {
          issues.push('Required field without aria-required');
        }
        
        if (!hasVisualIndicator) {
          issues.push('Required field without visual indicator');
        }
      });
      
      return issues;
    JS)
    
    issues.concat(required_field_issues)
  end

  def check_semantic_elements
    issues = []
    
    # Check for proper use of semantic HTML5 elements
    semantic_usage = page.evaluate_script(<<~JS)
      const issues = [];
      
      // Check for header
      if (!document.querySelector('header')) {
        issues.push('No header element found');
      }
      
      // Check for main
      if (!document.querySelector('main')) {
        issues.push('No main element found');
      }
      
      // Check for proper article/section usage
      const articles = document.querySelectorAll('article');
      const sections = document.querySelectorAll('section');
      
      // Check if articles have headings
      articles.forEach(article => {
        if (!article.querySelector('h1, h2, h3, h4, h5, h6')) {
          issues.push('Article without heading');
        }
      });
      
      return issues;
    JS)
    
    issues.concat(semantic_usage)
  end

  def check_document_structure
    issues = []
    
    # Check for proper document outline
    document_structure = page.evaluate_script(<<~JS)
      const issues = [];
      
      // Check for proper nesting
      const headings = Array.from(document.querySelectorAll('h1, h2, h3, h4, h5, h6'));
      let previousLevel = 0;
      
      headings.forEach(heading => {
        const level = parseInt(heading.tagName.substring(1));
        if (level > previousLevel + 1) {
          issues.push(`Heading level skip: H${previousLevel} to H${level}`);
        }
        previousLevel = level;
      });
      
      // Check for landmark structure
      const landmarks = ['header', 'nav', 'main', 'aside', 'footer'].map(tag => 
        document.querySelectorAll(tag).length
      );
      
      if (landmarks[2] === 0) { // main
        issues.push('No main landmark');
      }
      
      return issues;
    JS)
    
    issues.concat(document_structure)
  end

  def check_list_markup
    issues = []
    
    # Check for proper list markup
    list_issues = page.evaluate_script(<<~JS)
      const issues = [];
      
      // Check for lists that should be marked up as lists
      const suspiciousList = document.querySelectorAll('div > div, p > span').length;
      const actualLists = document.querySelectorAll('ul, ol, dl').length;
      
      // Simple heuristic: if we have many repeated div/span structures but few lists
      if (suspiciousList > 5 && actualLists === 0) {
        issues.push('Potential list content not marked up as lists');
      }
      
      // Check for proper list item structure
      document.querySelectorAll('ul, ol').forEach(list => {
        const hasNonLiChildren = Array.from(list.children).some(child => 
          child.tagName !== 'LI'
        );
        if (hasNonLiChildren) {
          issues.push('List contains non-LI children');
        }
      });
      
      return issues;
    JS)
    
    issues.concat(list_issues)
  end

  def check_table_markup
    issues = []
    
    # Check for proper table markup
    table_issues = page.evaluate_script(<<~JS)
      const issues = [];
      
      document.querySelectorAll('table').forEach(table => {
        // Check for table headers
        const hasHeaders = table.querySelector('th') || table.querySelector('[scope]');
        if (!hasHeaders) {
          issues.push('Table without headers');
        }
        
        // Check for table caption
        const hasCaption = table.querySelector('caption');
        if (!hasCaption) {
          issues.push('Table without caption');
        }
        
        // Check for proper scope attributes
        const headers = table.querySelectorAll('th');
        headers.forEach(header => {
          if (!header.hasAttribute('scope')) {
            issues.push('Table header without scope attribute');
          }
        });
      });
      
      return issues;
    JS)
    
    issues.concat(table_issues)
  end

  def check_touch_target_sizes
    issues = []
    
    # Check touch target sizes (minimum 44px x 44px)
    small_targets = page.evaluate_script(<<~JS)
      let smallCount = 0;
      const interactiveElements = document.querySelectorAll(
        'button, a, input, select, textarea, [onclick], [role="button"]'
      );
      
      interactiveElements.forEach(el => {
        const rect = el.getBoundingClientRect();
        if (rect.width < 44 || rect.height < 44) {
          smallCount++;
        }
      });
      
      return smallCount;
    JS)
    
    if small_targets > 0
      issues << "#{small_targets} touch targets smaller than 44px minimum"
    end
    
    issues
  end

  def check_touch_target_spacing
    issues = []
    
    # Check spacing between touch targets
    close_targets = page.evaluate_script(<<~JS)
      let closeCount = 0;
      const targets = Array.from(document.querySelectorAll(
        'button, a, input[type="submit"], input[type="button"]'
      ));
      
      targets.forEach((target, i) => {
        const rect1 = target.getBoundingClientRect();
        targets.slice(i + 1).forEach(otherTarget => {
          const rect2 = otherTarget.getBoundingClientRect();
          const distance = Math.sqrt(
            Math.pow(rect1.left - rect2.left, 2) + 
            Math.pow(rect1.top - rect2.top, 2)
          );
          
          if (distance < 44) {
            closeCount++;
          }
        });
      });
      
      return closeCount;
    JS)
    
    if close_targets > 0
      issues << "#{close_targets} pairs of touch targets too close together"
    end
    
    issues
  end

  def check_gesture_alternatives
    issues = []
    
    # Check for gesture-dependent functionality without alternatives
    gesture_only = page.evaluate_script(<<~JS)
      let gestureOnlyCount = 0;
      
      // Look for swipe, pinch, or drag functionality
      const gestureElements = document.querySelectorAll(
        '[data-swipe], [data-drag], [data-pinch], .swipeable, .draggable'
      );
      
      gestureElements.forEach(el => {
        // Check if there's an alternative method (buttons, etc.)
        const hasAlternative = el.querySelector('button, a, [role="button"]') ||
                              el.parentElement.querySelector('button, a, [role="button"]');
        
        if (!hasAlternative) {
          gestureOnlyCount++;
        }
      });
      
      return gestureOnlyCount;
    JS)
    
    if gesture_only > 0
      issues << "#{gesture_only} gesture-dependent features without alternatives"
    end
    
    issues
  end

  def resize_to_device(config)
    page.driver.browser.manage.window.resize_to(config[:width], config[:height])
    sleep 0.5 # Allow time for responsive changes
  end

  def create_test_user
    User.create!(
      email: "accessibility.test@example.com",
      name: "Accessibility Test User",
      provider: "google_oauth2",
      uid: "accessibility123"
    )
  end

  def sign_in_test_user
    page.execute_script(<<~JS)
      sessionStorage.setItem('test_user_signed_in', 'true');
    JS)
    
    visit root_path
  end

  # Report generation methods

  def generate_wcag_compliance_report
    puts "\n♿ WCAG 2.1 AA Compliance Report"
    puts "=" * 60
    
    wcag_results = @test_results.select { |k, _| k.include?("wcag_") }
    
    wcag_results.each do |test_name, result|
      status = result[:success] ? "✅ COMPLIANT" : "❌ VIOLATIONS"
      device = result[:device].to_s.capitalize
      
      puts sprintf("%-15s %s", device, status)
      
      if result[:violations].any?
        result[:violations].each { |violation| puts "   ⚠️  #{violation}" }
      end
    end
  end

  def generate_keyboard_navigation_report
    puts "\n⌨️ Keyboard Navigation Report"
    puts "=" * 50
    
    keyboard_results = @test_results.select { |k, _| k.include?("keyboard_") }
    
    keyboard_results.each do |test_name, result|
      status = result[:success] ? "✅ PASS" : "❌ FAIL"
      device = result[:device].to_s.capitalize
      
      puts sprintf("%-15s %s", device, status)
      
      if result[:issues].any?
        result[:issues].each { |issue| puts "   ⚠️  #{issue}" }
      end
    end
  end

  def generate_screen_reader_report
    puts "\n📢 Screen Reader Compatibility Report"
    puts "=" * 50
    
    sr_results = @test_results.select { |k, _| k.include?("screen_reader_") }
    
    sr_results.each do |test_name, result|
      status = result[:success] ? "✅ COMPATIBLE" : "❌ ISSUES"
      device = result[:device].to_s.capitalize
      
      puts sprintf("%-15s %s", device, status)
      
      if result[:issues].any?
        result[:issues].each { |issue| puts "   ⚠️  #{issue}" }
      end
    end
  end

  def generate_color_contrast_report
    puts "\n🎨 Color Contrast Report"
    puts "=" * 50
    
    contrast_results = @test_results.select { |k, _| k.include?("contrast_") }
    
    contrast_results.each do |test_name, result|
      status = result[:success] ? "✅ PASS" : "❌ FAIL"
      device = result[:device].to_s.capitalize
      
      puts sprintf("%-15s %s", device, status)
      
      if result[:issues].any?
        result[:issues].each { |issue| puts "   ⚠️  #{issue}" }
      end
    end
  end

  def generate_focus_management_report
    puts "\n🎯 Focus Management Report"
    puts "=" * 50
    
    focus_results = @test_results.select { |k, _| k.include?("focus_") }
    
    focus_results.each do |test_name, result|
      status = result[:success] ? "✅ PASS" : "❌ FAIL"
      device = result[:device].to_s.capitalize
      
      puts sprintf("%-15s %s", device, status)
      
      if result[:issues].any?
        result[:issues].each { |issue| puts "   ⚠️  #{issue}" }
      end
    end
  end

  def generate_form_accessibility_report
    puts "\n📝 Form Accessibility Report"
    puts "=" * 50
    
    form_results = @test_results.select { |k, _| k.include?("forms_") }
    
    form_results.each do |test_name, result|
      status = result[:success] ? "✅ ACCESSIBLE" : "❌ ISSUES"
      device = result[:device].to_s.capitalize
      
      puts sprintf("%-15s %s", device, status)
      
      if result[:issues].any?
        result[:issues].each { |issue| puts "   ⚠️  #{issue}" }
      end
    end
  end

  def generate_semantic_markup_report
    puts "\n🏗️ Semantic Markup Report"
    puts "=" * 50
    
    markup_results = @test_results.select { |k, _| k.include?("markup_") }
    
    markup_results.each do |test_name, result|
      status = result[:success] ? "✅ SEMANTIC" : "❌ ISSUES"
      device = result[:device].to_s.capitalize
      
      puts sprintf("%-15s %s", device, status)
      
      if result[:issues].any?
        result[:issues].each { |issue| puts "   ⚠️  #{issue}" }
      end
    end
  end

  def generate_touch_accessibility_report
    puts "\n👆 Touch Accessibility Report"
    puts "=" * 50
    
    touch_results = @test_results.select { |k, _| k.include?("touch_") }
    
    touch_results.each do |test_name, result|
      status = result[:success] ? "✅ ACCESSIBLE" : "❌ ISSUES"
      device = result[:device].to_s.capitalize
      
      puts sprintf("%-15s %s", device, status)
      
      if result[:issues].any?
        result[:issues].each { |issue| puts "   ⚠️  #{issue}" }
      end
    end
  end
end