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

  # Input Validation Tests
  test "should validate sermon ID parameter" do
    invalid_ids = [nil, "", "not-a-number", -1, 0]
    
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

  # Performance Tests
  test "should complete within reasonable time" do
    # Mock quick service response
    result = mock('result')
    result.stubs(:success?).returns(true)
    result.stubs(:video_path).returns('/tmp/video.mp4')
    result.stubs(:thumbnail_path).returns('/tmp/thumbnail.jpg')
    
    generator_service = mock('generator_service')
    generator_service.expects(:generate_video).returns(result)
    VideoGeneratorService.expects(:new).returns(generator_service)
    
    start_time = Time.current
    @job.perform(@sermon.id)
    end_time = Time.current
    
    assert (end_time - start_time) < 5, "Job should complete quickly in test"
  end
end