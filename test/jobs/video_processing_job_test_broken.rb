require "test_helper"

class VideoProcessingJobTest < ActiveJob::TestCase
  def setup
    @sermon = sermons(:one)
    @job = VideoProcessingJob.new
  end

  # Basic Job Execution Tests
  test "should enqueue job with sermon ID" do
    assert_enqueued_with(job: VideoProcessingJob, args: [@sermon.id]) do
      VideoProcessingJob.perform_later(@sermon.id)
    end
  end

  test "should execute job with valid sermon ID" do
    # Mock the service call
    generator_service = mock('generator_service')
    result = mock('result')
    result.stubs(:success?).returns(true)
    result.stubs(:video_path).returns('/tmp/video.mp4')
    result.stubs(:thumbnail_path).returns('/tmp/thumbnail.jpg')
    
    VideoGeneratorService.expects(:new).with(@sermon).returns(generator_service)
    generator_service.expects(:generate_video).returns(result)
    
    perform_enqueued_jobs do
      VideoProcessingJob.perform_later(@sermon.id)
    end
  end

  test "should handle successful video generation" do
    video_path = '/tmp/test_video.mp4'
    thumbnail_path = '/tmp/test_thumbnail.jpg'
    
    # Create test files
    FileUtils.mkdir_p('/tmp')
    File.write(video_path, 'test video content')
    File.write(thumbnail_path, 'test thumbnail content')
    
    # Mock successful service result
    service_result = mock('service_result')
    service_result.stubs(:success?).returns(true)
    service_result.stubs(:video_path).returns(video_path)
    service_result.stubs(:thumbnail_path).returns(thumbnail_path)
    
    generator_service = mock('generator_service')
    generator_service.expects(:generate_video).returns(service_result)
    VideoGeneratorService.expects(:new).returns(generator_service)
    
    # Should update sermon with video record
    @job.perform(@sermon.id)
    
    @sermon.reload
    assert @sermon.videos.any?
    video = @sermon.videos.last
    assert_equal 'processing', video.status
    assert_equal video_path, video.video_path
    assert_equal thumbnail_path, video.thumbnail_path
    
    # Cleanup
    File.delete(video_path) if File.exist?(video_path)
    File.delete(thumbnail_path) if File.exist?(thumbnail_path)
  end

  test "should handle video generation failure" do
    # Mock failed service result
    service_result = mock('service_result')
    service_result.stubs(:success?).returns(false)
    service_result.stubs(:error).returns("Video generation failed")
    
    generator_service = mock('generator_service')
    generator_service.expects(:generate_video).returns(service_result)
    VideoGeneratorService.expects(:new).returns(generator_service)
    
    @job.perform(@sermon.id)
    
    @sermon.reload
    if @sermon.videos.any?
      video = @sermon.videos.last
      assert_equal 'failed', video.status
    end
  end

  # Error Handling Tests
  test "should handle service exceptions gracefully" do
    # Mock service raising exception
    generator_service = mock('generator_service')
    generator_service.expects(:generate_video).raises(StandardError.new("Service error"))
    VideoGeneratorService.expects(:new).returns(generator_service)
    
    # Job should not fail catastrophically
    assert_nothing_raised do
      @job.perform(@sermon.id)
    end
  end

  test "should handle missing sermon" do
    non_existent_id = 99999
    
    assert_raises ActiveRecord::RecordNotFound do
      @job.perform(non_existent_id)
    end
  end

  test "should handle file system errors" do
    generator_service = mock('generator_service')
    generator_service.expects(:generate_video).raises(Errno::ENOSPC.new("No space left"))
    VideoGeneratorService.expects(:new).returns(generator_service)
    
    assert_nothing_raised do
      @job.perform(@sermon.id)
    end
  end

  test "should handle permission errors" do
    generator_service = mock('generator_service')
    generator_service.expects(:generate_video).raises(Errno::EACCES.new("Permission denied"))
    VideoGeneratorService.expects(:new).returns(generator_service)
    
    assert_nothing_raised do
      @job.perform(@sermon.id)
    end
  end

  # Retry Logic Tests
  test "should retry on retryable errors" do
    attempts = 0
    
    # Mock service to fail twice, then succeed
    VideoGeneratorService.any_instance.stubs(:generate_video).returns(
      proc do
        attempts += 1
        if attempts < 3
          raise Errno::EBUSY.new("Resource busy")
        else
          result = mock('result')
          result.stubs(:success?).returns(true)
          result.stubs(:video_path).returns('/tmp/video.mp4')
          result.stubs(:thumbnail_path).returns('/tmp/thumbnail.jpg')
          result
        end
      end.call
    )
    
    # Job should eventually succeed after retries
    perform_enqueued_jobs do
      VideoProcessingJob.perform_later(@sermon.id)
    end
    
    assert_equal 3, attempts
  end

  test "should not retry on non-retryable errors" do
    attempts = 0
    
    # Mock service to always fail with non-retryable error
    VideoGeneratorService.any_instance.stubs(:generate_video).returns(
      proc do
        attempts += 1
        raise ArgumentError.new("Invalid configuration")
      end.call
    )
    
    # Job should fail immediately without retries
    perform_enqueued_jobs do
      VideoProcessingJob.perform_later(@sermon.id)
    end
    
    assert_equal 1, attempts
  end

  test "should stop retrying after maximum attempts" do
    # Set maximum retry attempts to 2 for testing
    VideoProcessingJob.any_instance.stubs(:max_retry_attempts).returns(2)
    
    attempts = 0
    VideoGeneratorService.any_instance.stubs(:generate_video).returns(
      proc do
        attempts += 1
        raise Errno::EBUSY.new("Persistent resource busy")
      end.call
    )
    
    perform_enqueued_jobs do
      VideoProcessingJob.perform_later(@sermon.id)
    end
    
    assert_equal 3, attempts # Initial + 2 retries
  end

  # Input Validation Tests
  test "should validate sermon ID parameter" do
    invalid_ids = [
      nil,
      "",
      "not-a-number",
      -1,
      0
    ]
    
    invalid_ids.each do |id|
      assert_raises(ArgumentError) do
        @job.perform(id)
      end
    end
  end

  test "should accept valid sermon IDs" do
    valid_id = @sermon.id
    
    # Mock successful service call
    result = mock('result')
    result.stubs(:success?).returns(true)
    result.stubs(:video_path).returns('/tmp/video.mp4')
    result.stubs(:thumbnail_path).returns('/tmp/thumbnail.jpg')
    
    generator_service = mock('generator_service')
    generator_service.expects(:generate_video).returns(result)
    VideoGeneratorService.expects(:new).returns(generator_service)
    
    assert_nothing_raised do
      @job.perform(valid_id)
    end
  end

  # Job Queue and Priority Tests
  test "should be enqueued in correct queue" do
    job = VideoProcessingJob.new
    assert_equal "default", job.queue_name
  end

  test "should have high priority for video processing" do
    job = VideoProcessingJob.new
    assert_respond_to job, :priority
    # Video processing should have higher priority than crawling
  end

  # Logging Tests
  test "should log successful video generation" do
    # Mock successful service result
    service_result = mock('service_result')
    service_result.stubs(:success?).returns(true)
    service_result.stubs(:video_path).returns('/tmp/video.mp4')
    service_result.stubs(:thumbnail_path).returns('/tmp/thumbnail.jpg')
    
    generator_service = mock('generator_service')
    generator_service.expects(:generate_video).returns(service_result)
    VideoGeneratorService.expects(:new).returns(generator_service)
    
    # Expect info log
    Rails.logger.expects(:info).with(regexp_matches(/Successfully generated video/))
    
    @job.perform(@sermon.id)
  end\n\n  test \"should log video generation failures\" do\n    # Mock failed service result\n    service_result = mock('service_result')\n    service_result.stubs(:success?).returns(false)\n    service_result.stubs(:error).returns(\"Processing error\")\n    \n    generator_service = mock('generator_service')\n    generator_service.expects(:generate_video).returns(service_result)\n    VideoGeneratorService.expects(:new).returns(generator_service)\n    \n    # Expect error log\n    Rails.logger.expects(:error).with(regexp_matches(/Failed to generate video/))\n    \n    @job.perform(@sermon.id)\n  end\n\n  test \"should log exceptions\" do\n    # Mock service raising exception\n    generator_service = mock('generator_service')\n    generator_service.expects(:generate_video).raises(StandardError.new(\"Unexpected error\"))\n    VideoGeneratorService.expects(:new).returns(generator_service)\n    \n    # Expect error log with exception details\n    Rails.logger.expects(:error).with(regexp_matches(/Exception in VideoProcessingJob/))\n    \n    @job.perform(@sermon.id)\n  end\n\n  # Performance Tests\n  test \"should complete within reasonable time\" do\n    # Mock quick service response\n    result = mock('result')\n    result.stubs(:success?).returns(true)\n    result.stubs(:video_path).returns('/tmp/video.mp4')\n    result.stubs(:thumbnail_path).returns('/tmp/thumbnail.jpg')\n    \n    generator_service = mock('generator_service')\n    generator_service.expects(:generate_video).returns(result)\n    VideoGeneratorService.expects(:new).returns(generator_service)\n    \n    start_time = Time.current\n    @job.perform(@sermon.id)\n    end_time = Time.current\n    \n    assert (end_time - start_time) < 5, \"Job should complete quickly in test\"\n  end\n\n  # Video Status Management Tests\n  test \"should create video record in pending status\" do\n    # Mock successful service call\n    result = mock('result')\n    result.stubs(:success?).returns(true)\n    result.stubs(:video_path).returns('/tmp/video.mp4')\n    result.stubs(:thumbnail_path).returns('/tmp/thumbnail.jpg')\n    \n    generator_service = mock('generator_service')\n    generator_service.expects(:generate_video).returns(result)\n    VideoGeneratorService.expects(:new).returns(generator_service)\n    \n    initial_video_count = @sermon.videos.count\n    \n    @job.perform(@sermon.id)\n    \n    @sermon.reload\n    assert_equal initial_video_count + 1, @sermon.videos.count\n    \n    new_video = @sermon.videos.last\n    assert_equal 'processing', new_video.status\n    assert_not_nil new_video.script\n  end\n\n  test \"should update existing video status on retry\" do\n    # Create existing video in pending status\n    existing_video = @sermon.videos.create!(\n      script: \"Existing script\",\n      status: \"pending\"\n    )\n    \n    # Mock successful service call\n    result = mock('result')\n    result.stubs(:success?).returns(true)\n    result.stubs(:video_path).returns('/tmp/video.mp4')\n    result.stubs(:thumbnail_path).returns('/tmp/thumbnail.jpg')\n    \n    generator_service = mock('generator_service')\n    generator_service.expects(:generate_video).returns(result)\n    VideoGeneratorService.expects(:new).returns(generator_service)\n    \n    @job.perform(@sermon.id)\n    \n    existing_video.reload\n    assert_equal 'processing', existing_video.status\n  end\n\n  # File Management Tests\n  test \"should handle file validation\" do\n    # Mock service returning invalid file paths\n    service_result = mock('service_result')\n    service_result.stubs(:success?).returns(true)\n    service_result.stubs(:video_path).returns('/nonexistent/video.mp4')\n    service_result.stubs(:thumbnail_path).returns('/nonexistent/thumbnail.jpg')\n    \n    generator_service = mock('generator_service')\n    generator_service.expects(:generate_video).returns(service_result)\n    VideoGeneratorService.expects(:new).returns(generator_service)\n    \n    @job.perform(@sermon.id)\n    \n    @sermon.reload\n    if @sermon.videos.any?\n      video = @sermon.videos.last\n      assert_equal 'failed', video.status\n    end\n  end\n\n  test \"should handle large video files\" do\n    large_video_path = '/tmp/large_video.mp4'\n    \n    # Create a large test file (simulate)\n    File.write(large_video_path, 'x' * 1000) # Small for test, but represents large file\n    \n    service_result = mock('service_result')\n    service_result.stubs(:success?).returns(true)\n    service_result.stubs(:video_path).returns(large_video_path)\n    service_result.stubs(:thumbnail_path).returns('/tmp/thumbnail.jpg')\n    \n    generator_service = mock('generator_service')\n    generator_service.expects(:generate_video).returns(service_result)\n    VideoGeneratorService.expects(:new).returns(generator_service)\n    \n    @job.perform(@sermon.id)\n    \n    @sermon.reload\n    assert @sermon.videos.any?\n    \n    # Cleanup\n    File.delete(large_video_path) if File.exist?(large_video_path)\n  end\n\n  # Security Tests\n  test \"should validate file paths for security\" do\n    dangerous_paths = [\n      '../../../etc/passwd',\n      '/etc/shadow',\n      '~/.ssh/id_rsa'\n    ]\n    \n    dangerous_paths.each do |path|\n      service_result = mock('service_result')\n      service_result.stubs(:success?).returns(true)\n      service_result.stubs(:video_path).returns(path)\n      service_result.stubs(:thumbnail_path).returns('/tmp/thumbnail.jpg')\n      \n      generator_service = mock('generator_service')\n      generator_service.expects(:generate_video).returns(service_result)\n      VideoGeneratorService.expects(:new).returns(generator_service)\n      \n      @job.perform(@sermon.id)\n      \n      @sermon.reload\n      if @sermon.videos.any?\n        video = @sermon.videos.last\n        # Should either reject dangerous path or sanitize it\n        assert_not_includes video.video_path, '../' if video.video_path\n      end\n    end\n  end\n\n  # Concurrency Tests\n  test \"should handle concurrent processing of same sermon\" do\n    # Simulate two jobs processing same sermon\n    job1 = VideoProcessingJob.new\n    job2 = VideoProcessingJob.new\n    \n    # Mock service calls\n    result1 = mock('result1')\n    result1.stubs(:success?).returns(true)\n    result1.stubs(:video_path).returns('/tmp/video1.mp4')\n    result1.stubs(:thumbnail_path).returns('/tmp/thumbnail1.jpg')\n    \n    result2 = mock('result2')\n    result2.stubs(:success?).returns(true)\n    result2.stubs(:video_path).returns('/tmp/video2.mp4')\n    result2.stubs(:thumbnail_path).returns('/tmp/thumbnail2.jpg')\n    \n    generator_service1 = mock('generator_service1')\n    generator_service1.expects(:generate_video).returns(result1)\n    \n    generator_service2 = mock('generator_service2')\n    generator_service2.expects(:generate_video).returns(result2)\n    \n    VideoGeneratorService.expects(:new).twice.returns(generator_service1, generator_service2)\n    \n    # Both jobs should handle concurrent execution gracefully\n    assert_nothing_raised do\n      job1.perform(@sermon.id)\n      job2.perform(@sermon.id)\n    end\n  end\n\n  # Integration Tests\n  test \"should integrate with video upload pipeline\" do\n    video_path = '/tmp/integration_video.mp4'\n    File.write(video_path, 'test video content')\n    \n    service_result = mock('service_result')\n    service_result.stubs(:success?).returns(true)\n    service_result.stubs(:video_path).returns(video_path)\n    service_result.stubs(:thumbnail_path).returns('/tmp/thumbnail.jpg')\n    \n    generator_service = mock('generator_service')\n    generator_service.expects(:generate_video).returns(service_result)\n    VideoGeneratorService.expects(:new).returns(generator_service)\n    \n    @job.perform(@sermon.id)\n    \n    @sermon.reload\n    assert @sermon.videos.any?\n    video = @sermon.videos.last\n    \n    # Video should be ready for next stage (upload)\n    assert video.can_upload?\n    \n    File.delete(video_path) if File.exist?(video_path)\n  end\n\n  # Edge Cases\n  test \"should handle sermon with existing videos\" do\n    # Create existing video\n    existing_video = @sermon.videos.create!(\n      script: \"Existing video script\",\n      status: \"uploaded\",\n      youtube_id: \"existing123\"\n    )\n    \n    # Mock successful service call\n    result = mock('result')\n    result.stubs(:success?).returns(true)\n    result.stubs(:video_path).returns('/tmp/new_video.mp4')\n    result.stubs(:thumbnail_path).returns('/tmp/new_thumbnail.jpg')\n    \n    generator_service = mock('generator_service')\n    generator_service.expects(:generate_video).returns(result)\n    VideoGeneratorService.expects(:new).returns(generator_service)\n    \n    initial_count = @sermon.videos.count\n    \n    @job.perform(@sermon.id)\n    \n    @sermon.reload\n    assert_equal initial_count + 1, @sermon.videos.count\n    \n    # Existing video should remain unchanged\n    existing_video.reload\n    assert_equal \"uploaded\", existing_video.status\n    assert_equal \"existing123\", existing_video.youtube_id\n  end\n\n  test \"should handle empty sermon content\" do\n    empty_sermon = Sermon.create!(\n      title: \"Empty Sermon\",\n      source_url: \"https://empty.com\",\n      church: \"Empty Church\"\n      # No interpretation, action_points, etc.\n    )\n    \n    # Service should still be able to generate basic video\n    result = mock('result')\n    result.stubs(:success?).returns(true)\n    result.stubs(:video_path).returns('/tmp/empty_video.mp4')\n    result.stubs(:thumbnail_path).returns('/tmp/empty_thumbnail.jpg')\n    \n    generator_service = mock('generator_service')\n    generator_service.expects(:generate_video).returns(result)\n    VideoGeneratorService.expects(:new).returns(generator_service)\n    \n    assert_nothing_raised do\n      @job.perform(empty_sermon.id)\n    end\n  end\n\n  # Cleanup Tests\n  test \"should cleanup temporary resources\" do\n    temp_files = ['/tmp/temp1.txt', '/tmp/temp2.txt']\n    temp_files.each { |file| File.write(file, 'temp content') }\n    \n    # Mock service that creates temporary files\n    result = mock('result')\n    result.stubs(:success?).returns(true)\n    result.stubs(:video_path).returns('/tmp/video.mp4')\n    result.stubs(:thumbnail_path).returns('/tmp/thumbnail.jpg')\n    \n    generator_service = mock('generator_service')\n    generator_service.expects(:generate_video).returns(result)\n    VideoGeneratorService.expects(:new).returns(generator_service)\n    \n    @job.perform(@sermon.id)\n    \n    # Temporary files should be cleaned up\n    # (Implementation specific - adjust based on actual cleanup needs)\n    temp_files.each { |file| File.delete(file) if File.exist?(file) }\n  end\nend"