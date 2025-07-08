#!/usr/bin/env ruby
# frozen_string_literal: true

# Cross-Platform Test Runner
# Orchestrates browser, device, and responsiveness testing

require "fileutils"
require "json"
require "time"

class CrossPlatformTestRunner
  attr_reader :results, :start_time, :end_time

  BROWSER_TESTS = [
    "cross_browser_test.rb",
    "browser_compatibility_test.rb"
  ].freeze

  DEVICE_TESTS = [
    "mobile_device_test.rb",
    "responsive_design_test.rb"
  ].freeze

  ACCESSIBILITY_TESTS = [
    # Add accessibility test files when created
  ].freeze

  def initialize
    @results = {}
    @start_time = nil
    @end_time = nil
    @test_directory = File.dirname(__FILE__)
  end

  def run_all_tests
    puts "🚀 Starting Cross-Platform Test Suite for Words of Truth"
    puts "=" * 80
    puts "Testing browsers, devices, and responsive design"
    puts "=" * 80

    @start_time = Time.current
    
    run_browser_tests
    run_device_tests
    run_accessibility_tests
    
    @end_time = Time.current
    generate_comprehensive_report
  end

  def run_browser_tests
    puts "\n🌐 Running Browser Compatibility Tests"
    puts "-" * 50
    
    BROWSER_TESTS.each do |test_file|
      run_test_file(test_file, "browser")
    end
  end

  def run_device_tests
    puts "\n📱 Running Device and Responsive Tests"
    puts "-" * 50
    
    DEVICE_TESTS.each do |test_file|
      run_test_file(test_file, "device")
    end
  end

  def run_accessibility_tests
    puts "\n♿ Running Accessibility Tests"
    puts "-" * 50
    
    if ACCESSIBILITY_TESTS.any?
      ACCESSIBILITY_TESTS.each do |test_file|
        run_test_file(test_file, "accessibility")
      end
    else
      puts "No accessibility tests configured yet"
    end
  end

  def run_specific_test_type(test_type)
    @start_time = Time.current
    
    case test_type.downcase
    when "browser", "browsers"
      run_browser_tests
    when "device", "devices", "mobile"
      run_device_tests
    when "responsive", "responsiveness"
      run_test_file("responsive_design_test.rb", "responsive")
    when "accessibility", "a11y"
      run_accessibility_tests
    else
      puts "❌ Unknown test type: #{test_type}"
      puts "Available types: browser, device, responsive, accessibility"
      return false
    end
    
    @end_time = Time.current
    generate_summary_report
    true
  end

  def run_quick_test
    puts "⚡ Running Quick Cross-Platform Test"
    puts "-" * 40
    
    @start_time = Time.current
    
    # Run essential tests only
    essential_tests = [
      "cross_browser_test.rb",
      "mobile_device_test.rb"
    ]
    
    essential_tests.each do |test_file|
      if File.exist?(File.join(@test_directory, test_file))
        run_test_file(test_file, "essential")
      end
    end
    
    @end_time = Time.current
    generate_summary_report
  end

  private

  def run_test_file(test_file, category)
    test_path = File.join(@test_directory, test_file)
    test_name = File.basename(test_file, ".rb")
    
    unless File.exist?(test_path)
      puts "⚠️  Test file not found: #{test_file}"
      return
    end
    
    puts "🧪 Running #{test_name}..."
    
    start_time = Time.current
    
    # Run the test using Rails test runner
    result = system("cd #{Rails.root} && bundle exec rails test #{test_path}")
    
    end_time = Time.current
    duration = end_time - start_time
    
    @results[test_name] = {
      category: category,
      success: result,
      duration: duration,
      file_path: test_path,
      timestamp: start_time
    }

    status = result ? "✅ PASS" : "❌ FAIL"
    puts "#{status} #{test_name} (#{duration.round(2)}s)"
  end

  def generate_comprehensive_report
    puts "\n" + "=" * 80
    puts "🏁 CROSS-PLATFORM TEST SUITE COMPLETE"
    puts "=" * 80
    
    total_duration = @end_time - @start_time
    successful_tests = @results.values.count { |r| r[:success] }
    failed_tests = @results.values.count { |r| !r[:success] }
    
    puts "Total runtime: #{format_duration(total_duration)}"
    puts "Total tests: #{@results.count}"
    puts "✅ Successful: #{successful_tests}"
    puts "❌ Failed: #{failed_tests}"
    puts "Success rate: #{((successful_tests.to_f / @results.count) * 100).round(1)}%"
    
    # Group results by category
    by_category = @results.group_by { |_, result| result[:category] }
    
    puts "\n📊 RESULTS BY CATEGORY"
    puts "-" * 50
    
    by_category.each do |category, tests|
      successful = tests.count { |_, r| r[:success] }
      total = tests.count
      puts sprintf("%-15s %d/%d tests passed", category.capitalize, successful, total)
    end
    
    puts "\n📋 DETAILED RESULTS"
    puts "-" * 50
    
    @results.each do |test_name, result|
      status = result[:success] ? "✅ PASS" : "❌ FAIL"
      category = result[:category].upcase
      duration = result[:duration].round(2)
      
      puts sprintf("%-30s %-12s %s %8ss", test_name, "[#{category}]", status, duration)
    end
    
    if failed_tests > 0
      puts "\n🔍 FAILED TESTS"
      puts "-" * 50
      @results.select { |_, r| !r[:success] }.each do |test_name, result|
        puts "❌ #{test_name} (#{result[:category]})"
        puts "   File: #{result[:file_path]}"
        puts "   Duration: #{result[:duration].round(2)}s"
      end
    end

    generate_cross_platform_analysis
    save_results_to_file
    generate_html_report

    puts "\n" + "=" * 80
    if failed_tests == 0
      puts "🎉 ALL CROSS-PLATFORM TESTS PASSED!"
      puts "   Your application works great across browsers and devices!"
    else
      puts "⚠️  SOME TESTS FAILED"
      puts "   Review the failures above to improve cross-platform compatibility"
    end
    puts "=" * 80
  end

  def generate_summary_report
    puts "\n📊 Test Summary"
    puts "-" * 30
    
    total_duration = @end_time - @start_time
    successful_tests = @results.values.count { |r| r[:success] }
    failed_tests = @results.values.count { |r| !r[:success] }
    
    puts "Duration: #{format_duration(total_duration)}"
    puts "✅ Passed: #{successful_tests}"
    puts "❌ Failed: #{failed_tests}"
    
    if failed_tests > 0
      puts "\nFailed tests:"
      @results.select { |_, r| !r[:success] }.each do |test_name, _|
        puts "  - #{test_name}"
      end
    end
  end

  def generate_cross_platform_analysis
    puts "\n🔍 CROSS-PLATFORM ANALYSIS"
    puts "-" * 50
    
    # Analyze test patterns
    browser_tests = @results.select { |_, r| r[:category] == "browser" }
    device_tests = @results.select { |_, r| r[:category] == "device" }
    
    puts "Browser Compatibility:"
    if browser_tests.all? { |_, r| r[:success] }
      puts "  ✅ All browsers supported"
    else
      puts "  ⚠️  Some browser compatibility issues found"
    end
    
    puts "Device Compatibility:"
    if device_tests.all? { |_, r| r[:success] }
      puts "  ✅ All devices supported"
    else
      puts "  ⚠️  Some device compatibility issues found"
    end
    
    # Performance analysis
    slowest_test = @results.max_by { |_, r| r[:duration] }
    fastest_test = @results.min_by { |_, r| r[:duration] }
    
    puts "\nPerformance:"
    puts "  Slowest test: #{slowest_test[0]} (#{slowest_test[1][:duration].round(2)}s)"
    puts "  Fastest test: #{fastest_test[0]} (#{fastest_test[1][:duration].round(2)}s)"
    
    # Recommendations
    puts "\n💡 RECOMMENDATIONS"
    puts "-" * 50
    
    if @results.any? { |_, r| !r[:success] }
      puts "1. Review failed tests and fix compatibility issues"
      puts "2. Test on actual devices when possible"
      puts "3. Consider progressive enhancement for unsupported features"
    else
      puts "1. Great job! Your application has excellent cross-platform support"
      puts "2. Consider adding visual regression tests"
      puts "3. Monitor real user analytics for device-specific issues"
    end
  end

  def save_results_to_file
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    results_file = File.join(@test_directory, "cross_platform_results_#{timestamp}.json")
    
    detailed_results = {
      summary: {
        total_tests: @results.count,
        successful_tests: @results.values.count { |r| r[:success] },
        failed_tests: @results.values.count { |r| !r[:success] },
        total_duration: @end_time - @start_time,
        start_time: @start_time.iso8601,
        end_time: @end_time.iso8601
      },
      test_results: @results.transform_values do |result|
        {
          category: result[:category],
          success: result[:success],
          duration: result[:duration],
          file_path: result[:file_path],
          timestamp: result[:timestamp].iso8601
        }
      end,
      environment: {
        ruby_version: RUBY_VERSION,
        rails_version: Rails.version,
        platform: RUBY_PLATFORM,
        date: Date.current.iso8601
      }
    }

    File.write(results_file, JSON.pretty_generate(detailed_results))
    puts "\n📄 Detailed results saved to: #{results_file}"
  end

  def generate_html_report
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    html_file = File.join(@test_directory, "cross_platform_report_#{timestamp}.html")
    
    html_content = generate_html_content
    File.write(html_file, html_content)
    puts "📄 HTML report generated: #{html_file}"
    
    # Try to open the report in the default browser
    if RUBY_PLATFORM.include?("darwin")
      system("open #{html_file}")
    elsif RUBY_PLATFORM.include?("linux")
      system("xdg-open #{html_file}")
    elsif RUBY_PLATFORM.include?("mswin") || RUBY_PLATFORM.include?("mingw")
      system("start #{html_file}")
    end
  end

  def generate_html_content
    successful_tests = @results.values.count { |r| r[:success] }
    failed_tests = @results.values.count { |r| !r[:success] }
    success_rate = ((successful_tests.to_f / @results.count) * 100).round(1)
    
    <<~HTML
      <!DOCTYPE html>
      <html lang="en">
      <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>Cross-Platform Test Report - Words of Truth</title>
          <style>
              body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
              .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; }
              .header { text-align: center; margin-bottom: 30px; }
              .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 30px; }
              .summary-card { background: #f8f9fa; padding: 20px; border-radius: 8px; text-align: center; }
              .success { background: #d4edda; color: #155724; }
              .warning { background: #fff3cd; color: #856404; }
              .danger { background: #f8d7da; color: #721c24; }
              .results-table { width: 100%; border-collapse: collapse; margin-bottom: 30px; }
              .results-table th, .results-table td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
              .results-table th { background: #f8f9fa; }
              .status-pass { color: #28a745; font-weight: bold; }
              .status-fail { color: #dc3545; font-weight: bold; }
              .category { background: #007bff; color: white; padding: 4px 8px; border-radius: 4px; font-size: 12px; }
              .recommendations { background: #e7f3ff; padding: 20px; border-radius: 8px; border-left: 4px solid #007bff; }
          </style>
      </head>
      <body>
          <div class="container">
              <div class="header">
                  <h1>🚀 Cross-Platform Test Report</h1>
                  <h2>Words of Truth Application</h2>
                  <p>Generated on #{Time.current.strftime('%B %d, %Y at %I:%M %p')}</p>
              </div>
              
              <div class="summary">
                  <div class="summary-card">
                      <h3>Total Tests</h3>
                      <h2>#{@results.count}</h2>
                  </div>
                  <div class="summary-card success">
                      <h3>Passed</h3>
                      <h2>#{successful_tests}</h2>
                  </div>
                  <div class="summary-card #{failed_tests > 0 ? 'danger' : 'success'}">
                      <h3>Failed</h3>
                      <h2>#{failed_tests}</h2>
                  </div>
                  <div class="summary-card">
                      <h3>Success Rate</h3>
                      <h2>#{success_rate}%</h2>
                  </div>
              </div>
              
              <h3>📋 Test Results</h3>
              <table class="results-table">
                  <thead>
                      <tr>
                          <th>Test Name</th>
                          <th>Category</th>
                          <th>Status</th>
                          <th>Duration</th>
                          <th>Timestamp</th>
                      </tr>
                  </thead>
                  <tbody>
                      #{generate_table_rows}
                  </tbody>
              </table>
              
              #{generate_recommendations_html}
              
              <div style="text-align: center; margin-top: 30px; color: #666;">
                  <p>Generated by Words of Truth Cross-Platform Test Suite</p>
              </div>
          </div>
      </body>
      </html>
    HTML
  end

  def generate_table_rows
    @results.map do |test_name, result|
      status_class = result[:success] ? "status-pass" : "status-fail"
      status_text = result[:success] ? "✅ PASS" : "❌ FAIL"
      
      <<~HTML
        <tr>
            <td>#{test_name}</td>
            <td><span class="category">#{result[:category].upcase}</span></td>
            <td class="#{status_class}">#{status_text}</td>
            <td>#{result[:duration].round(2)}s</td>
            <td>#{result[:timestamp].strftime('%H:%M:%S')}</td>
        </tr>
      HTML
    end.join
  end

  def generate_recommendations_html
    if @results.any? { |_, r| !r[:success] }
      <<~HTML
        <div class="recommendations">
            <h3>💡 Recommendations</h3>
            <ul>
                <li>Review failed tests and fix compatibility issues</li>
                <li>Test on actual devices when possible</li>
                <li>Consider progressive enhancement for unsupported features</li>
                <li>Update browser support documentation</li>
            </ul>
        </div>
      HTML
    else
      <<~HTML
        <div class="recommendations">
            <h3>🎉 Excellent Cross-Platform Support!</h3>
            <ul>
                <li>All tests passed - great job!</li>
                <li>Consider adding visual regression tests</li>
                <li>Monitor real user analytics for device-specific issues</li>
                <li>Keep testing with new browser versions</li>
            </ul>
        </div>
      HTML
    end
  end

  def format_duration(seconds)
    if seconds < 60
      "#{seconds.round(2)}s"
    else
      minutes = (seconds / 60).floor
      remaining_seconds = (seconds % 60).round
      "#{minutes}m #{remaining_seconds}s"
    end
  end
end

# Command line interface
if ARGV.length == 0
  # Run all tests
  runner = CrossPlatformTestRunner.new
  runner.run_all_tests
  exit runner.results.values.all? { |r| r[:success] } ? 0 : 1
elsif ARGV[0] == "--help" || ARGV[0] == "-h"
  puts <<~HELP
    Words of Truth Cross-Platform Test Runner
    
    Usage:
      ruby run_cross_platform_tests.rb                    # Run all tests
      ruby run_cross_platform_tests.rb <type>             # Run specific test type
      ruby run_cross_platform_tests.rb --quick            # Run quick essential tests
      ruby run_cross_platform_tests.rb --help             # Show this help
    
    Test Types:
      browser        Run browser compatibility tests
      device         Run mobile and device tests  
      responsive     Run responsive design tests
      accessibility  Run accessibility tests
    
    Examples:
      ruby run_cross_platform_tests.rb browser
      ruby run_cross_platform_tests.rb device
      ruby run_cross_platform_tests.rb --quick
    
    Output:
      - Console report with detailed results
      - JSON file with raw test data
      - HTML report that opens in browser
  HELP
elsif ARGV[0] == "--quick" || ARGV[0] == "-q"
  runner = CrossPlatformTestRunner.new
  runner.run_quick_test
  exit runner.results.values.all? { |r| r[:success] } ? 0 : 1
else
  # Run specific test type
  runner = CrossPlatformTestRunner.new
  success = runner.run_specific_test_type(ARGV[0])
  exit(success ? 0 : 1)
end
    HTML
  end

  def format_duration(seconds)
    if seconds < 60
      "#{seconds.round(2)}s"
    else
      minutes = (seconds / 60).floor
      remaining_seconds = (seconds % 60).round
      "#{minutes}m #{remaining_seconds}s"
    end
  end
end

# Command line interface
if ARGV.length == 0
  # Run all tests
  runner = CrossPlatformTestRunner.new
  runner.run_all_tests
  exit runner.results.values.all? { |r| r[:success] } ? 0 : 1
elsif ARGV[0] == "--help" || ARGV[0] == "-h"
  puts <<~HELP
    Words of Truth Cross-Platform Test Runner
    
    Usage:
      ruby run_cross_platform_tests.rb                    # Run all tests
      ruby run_cross_platform_tests.rb <type>             # Run specific test type
      ruby run_cross_platform_tests.rb --quick            # Run quick essential tests
      ruby run_cross_platform_tests.rb --help             # Show this help
    
    Test Types:
      browser        Run browser compatibility tests
      device         Run mobile and device tests  
      responsive     Run responsive design tests
      accessibility  Run accessibility tests
    
    Examples:
      ruby run_cross_platform_tests.rb browser
      ruby run_cross_platform_tests.rb device
      ruby run_cross_platform_tests.rb --quick
    
    Output:
      - Console report with detailed results
      - JSON file with raw test data
      - HTML report that opens in browser
  HELP
elsif ARGV[0] == "--quick" || ARGV[0] == "-q"
  runner = CrossPlatformTestRunner.new
  runner.run_quick_test
  exit runner.results.values.all? { |r| r[:success] } ? 0 : 1
else
  # Run specific test type
  runner = CrossPlatformTestRunner.new
  success = runner.run_specific_test_type(ARGV[0])
  exit(success ? 0 : 1)
end