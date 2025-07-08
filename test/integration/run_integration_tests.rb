#!/usr/bin/env ruby
# frozen_string_literal: true

# Integration Test Runner
# Runs all integration tests with performance monitoring and reporting

require "fileutils"
require "json"

class IntegrationTestRunner
  attr_reader :results, :start_time, :end_time

  def initialize
    @results = {}
    @start_time = nil
    @end_time = nil
    @test_files = Dir.glob(File.join(__dir__, "*_test.rb")).reject { |f| f.include?("run_integration_tests") }
  end

  def run_all_tests
    puts "🚀 Starting Words of Truth Integration Test Suite"
    puts "=" * 70
    puts "Total test files: #{@test_files.count}"
    puts "Test files:"
    @test_files.each { |f| puts "  - #{File.basename(f)}" }
    puts "=" * 70

    @start_time = Time.now
    
    @test_files.each do |test_file|
      run_test_file(test_file)
    end

    @end_time = Time.now
    generate_summary_report
  end

  def run_test_file(test_file)
    test_name = File.basename(test_file, ".rb")
    puts "\n📋 Running #{test_name}..."
    
    start_time = Time.now
    
    # Run the test file
    result = system("bundle exec ruby -Itest #{test_file}")
    
    end_time = Time.now
    duration = end_time - start_time
    
    @results[test_name] = {
      success: result,
      duration: duration,
      file_path: test_file
    }

    if result
      puts "✅ #{test_name} completed successfully (#{duration.round(2)}s)"
    else
      puts "❌ #{test_name} failed (#{duration.round(2)}s)"
    end
  end

  def generate_summary_report
    puts "\n" + "=" * 70
    puts "🏁 INTEGRATION TEST SUITE SUMMARY"
    puts "=" * 70
    
    total_duration = @end_time - @start_time
    successful_tests = @results.values.count { |r| r[:success] }
    failed_tests = @results.values.count { |r| !r[:success] }
    
    puts "Total runtime: #{total_duration.round(2)}s"
    puts "Total tests: #{@results.count}"
    puts "✅ Successful: #{successful_tests}"
    puts "❌ Failed: #{failed_tests}"
    puts "Success rate: #{((successful_tests.to_f / @results.count) * 100).round(1)}%"
    
    puts "\n📊 DETAILED RESULTS"
    puts "-" * 70
    
    @results.each do |test_name, result|
      status = result[:success] ? "✅ PASS" : "❌ FAIL"
      duration = result[:duration].round(2)
      puts sprintf("%-50s %s %8ss", test_name, status, duration)
    end
    
    if failed_tests > 0
      puts "\n🔍 FAILED TESTS"
      puts "-" * 70
      @results.select { |_, r| !r[:success] }.each do |test_name, result|
        puts "❌ #{test_name}"
        puts "   File: #{result[:file_path]}"
        puts "   Duration: #{result[:duration].round(2)}s"
      end
    end

    puts "\n🎯 PERFORMANCE ANALYSIS"
    puts "-" * 70
    
    slowest_tests = @results.sort_by { |_, r| -r[:duration] }.first(3)
    puts "Slowest tests:"
    slowest_tests.each_with_index do |(test_name, result), index|
      puts "  #{index + 1}. #{test_name}: #{result[:duration].round(2)}s"
    end
    
    fastest_tests = @results.sort_by { |_, r| r[:duration] }.first(3)
    puts "\nFastest tests:"
    fastest_tests.each_with_index do |(test_name, result), index|
      puts "  #{index + 1}. #{test_name}: #{result[:duration].round(2)}s"
    end

    # Save detailed results to JSON
    save_results_to_file

    puts "\n" + "=" * 70
    if failed_tests == 0
      puts "🎉 ALL INTEGRATION TESTS PASSED!"
    else
      puts "⚠️  SOME TESTS FAILED - Please review the failures above"
    end
    puts "=" * 70
  end

  def save_results_to_file
    results_file = File.join(__dir__, "test_results_#{Time.now.strftime('%Y%m%d_%H%M%S')}.json")
    
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
          success: result[:success],
          duration: result[:duration],
          file_path: result[:file_path]
        }
      end
    }

    File.write(results_file, JSON.pretty_generate(detailed_results))
    puts "\n📄 Detailed results saved to: #{results_file}"
  end

  def run_specific_test(test_name)
    test_file = @test_files.find { |f| f.include?(test_name) }
    
    if test_file
      puts "🎯 Running specific test: #{test_name}"
      run_test_file(test_file)
      
      result = @results[File.basename(test_file, ".rb")]
      if result[:success]
        puts "✅ Test completed successfully!"
      else
        puts "❌ Test failed!"
        exit 1
      end
    else
      puts "❌ Test file not found: #{test_name}"
      puts "Available tests:"
      @test_files.each { |f| puts "  - #{File.basename(f, '.rb')}" }
      exit 1
    end
  end

  def run_by_category(category)
    matching_tests = @test_files.select { |f| f.include?(category) }
    
    if matching_tests.empty?
      puts "❌ No tests found for category: #{category}"
      exit 1
    end

    puts "🎯 Running tests for category: #{category}"
    puts "Matching tests: #{matching_tests.count}"
    
    @start_time = Time.now
    matching_tests.each { |test_file| run_test_file(test_file) }
    @end_time = Time.now
    
    generate_summary_report
  end
end

# Command line interface
if ARGV.length == 0
  # Run all tests
  runner = IntegrationTestRunner.new
  runner.run_all_tests
  exit runner.results.values.all? { |r| r[:success] } ? 0 : 1
elsif ARGV[0] == "--help" || ARGV[0] == "-h"
  puts <<~HELP
    Words of Truth Integration Test Runner
    
    Usage:
      ruby run_integration_tests.rb                    # Run all tests
      ruby run_integration_tests.rb <test_name>        # Run specific test
      ruby run_integration_tests.rb --category <cat>   # Run tests by category
      ruby run_integration_tests.rb --help            # Show this help
    
    Examples:
      ruby run_integration_tests.rb authentication_flow
      ruby run_integration_tests.rb --category api
      ruby run_integration_tests.rb text_notes_crud
    
    Available test categories:
      - authentication
      - text_notes
      - sermon
      - video
      - api
      - security
      - error
  HELP
elsif ARGV[0] == "--category"
  if ARGV[1]
    runner = IntegrationTestRunner.new
    runner.run_by_category(ARGV[1])
    exit runner.results.values.all? { |r| r[:success] } ? 0 : 1
  else
    puts "❌ Please specify a category after --category"
    exit 1
  end
else
  # Run specific test
  runner = IntegrationTestRunner.new
  runner.run_specific_test(ARGV[0])
end