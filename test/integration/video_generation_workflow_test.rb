# frozen_string_literal: true

require "test_helper"

class VideoGenerationWorkflowTest < ActionDispatch::IntegrationTest
  def setup
    super
    @user = create_authenticated_user
    @sermon = create_test_sermon(@user)
    @text_note = create_test_text_note(@user)
    @video_params = {
      script: "This is a test video script for spiritual content about faith and hope.",
      theme: "faith"
    }
  end

  test "complete video generation workflow from sermon" do
    stub_video_generation_success

    @performance_tracker.track("Complete Video Workflow") do
      assert_enqueued_with(job: OptimizedVideoProcessingJob) do
        post generate_video_path, params: { 
          sermon_id: @sermon.id,
          video: @video_params
        }
      end
    end

    assert_response :redirect
    follow_redirect!
    assert_includes response.body, "Video generation started"

    # Process the job
    perform_enqueued_jobs

    @sermon.reload
    video = @sermon.videos.last
    assert_not_nil video
    assert_equal "completed", video.status
    assert_not_nil video.video_file_path
    assert_not_nil video.thumbnail_path
  end

  test "video generation workflow from text note" do
    stub_video_generation_success

    @performance_tracker.track("Text Note Video Workflow") do
      assert_enqueued_with(job: TextNoteVideoJob) do
        post generate_text_note_video_path, params: { 
          text_note_id: @text_note.id,
          video: @video_params
        }
      end
    end

    assert_response :redirect
    follow_redirect!
    assert_includes response.body, "Video generation started"

    # Process the job
    perform_enqueued_jobs

    @text_note.reload
    assert_equal "completed", @text_note.status
    assert_not_nil @text_note.video_file_path
  end

  test "video generation with Korean content" do
    korean_sermon = create_test_sermon(@user, 
      title: "믿음의 삶",
      interpretation: "우리는 하나님을 믿고 살아가야 합니다. 믿음은 우리 삶의 기초입니다.",
      action_points: "1. 매일 기도하기 2. 성경 읽기 3. 사랑 실천하기"
    )

    stub_video_generation_success

    @performance_tracker.track("Korean Video Generation") do
      assert_enqueued_with(job: OptimizedVideoProcessingJob) do
        post generate_video_path, params: { 
          sermon_id: korean_sermon.id,
          video: @video_params.merge(language: "ko")
        }
      end
    end

    assert_response :redirect
    perform_enqueued_jobs

    korean_sermon.reload
    video = korean_sermon.videos.last
    assert_equal "completed", video.status
  end

  test "video generation failure handling" do
    stub_video_generation_failure

    @performance_tracker.track("Video Generation Failure") do
      assert_enqueued_with(job: OptimizedVideoProcessingJob) do
        post generate_video_path, params: { 
          sermon_id: @sermon.id,
          video: @video_params
        }
      end
    end

    perform_enqueued_jobs

    @sermon.reload
    video = @sermon.videos.last
    assert_equal "failed", video.status
    assert_not_nil video.error_message
  end

  test "video generation progress tracking" do
    video = create_test_video(@sermon, status: "processing")

    @performance_tracker.track("Video Progress Tracking") do
      xhr_get video_progress_path(video)
    end

    assert_response :success
    assert_equal "application/json", response.content_type

    progress_data = JSON.parse(response.body)
    assert progress_data.key?("status")
    assert progress_data.key?("progress_percentage")
    assert progress_data.key?("current_step")
    assert progress_data.key?("estimated_completion")
  end

  test "batch video generation" do
    sermons = 3.times.map { |i| create_test_sermon(@user, title: "Batch Sermon #{i}") }
    stub_video_generation_success

    @performance_tracker.track("Batch Video Generation") do
      assert_enqueued_jobs(3) do
        post batch_generate_videos_path, params: { 
          sermon_ids: sermons.map(&:id),
          video: @video_params
        }
      end
    end

    assert_response :redirect
    follow_redirect!
    assert_includes response.body, "3 video generation jobs started"

    perform_enqueued_jobs

    sermons.each(&:reload)
    sermons.each do |sermon|
      assert sermon.videos.any? { |v| v.status == "completed" }
    end
  end

  test "video generation with different themes" do
    themes = %w[faith hope love grace mercy trust peace joy]
    
    themes.each do |theme|
      sermon = create_test_sermon(@user, title: "#{theme.capitalize} Sermon")
      stub_video_generation_success

      @performance_tracker.track("Theme #{theme} Generation") do
        post generate_video_path, params: { 
          sermon_id: sermon.id,
          video: @video_params.merge(theme: theme)
        }
      end

      perform_enqueued_jobs
      
      sermon.reload
      video = sermon.videos.last
      assert_equal theme, video.theme
      assert_equal "completed", video.status
    end
  end

  test "video generation performance optimization" do
    # Test optimized video generation (should be faster than 30 seconds)
    stub_video_generation_success

    assert_performance_within(IntegrationTestHelper::PERFORMANCE_CONFIG[:video_generation]) do
      post generate_video_path, params: { 
        sermon_id: @sermon.id,
        video: @video_params
      }
      
      perform_enqueued_jobs
    end

    @sermon.reload
    video = @sermon.videos.last
    assert_equal "completed", video.status
  end

  test "video file validation and security" do
    # Test with malicious script content
    malicious_params = @video_params.merge(
      script: "<script>alert('xss')</script>Malicious video script"
    )

    assert_no_enqueued_jobs do
      post generate_video_path, params: { 
        sermon_id: @sermon.id,
        video: malicious_params
      }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "contains potentially malicious content"
  end

  test "video generation rate limiting" do
    # Test rate limiting for video generation requests
    10.times do |i|
      sermon = create_test_sermon(@user, title: "Rate Limit Test #{i}")
      post generate_video_path, params: { 
        sermon_id: sermon.id,
        video: @video_params
      }
    end

    # Next request should be rate limited
    post generate_video_path, params: { 
      sermon_id: @sermon.id,
      video: @video_params
    }

    assert_response :too_many_requests
    assert_includes response.body, "Rate limit exceeded"
  end

  test "concurrent video generation" do
    sermons = 3.times.map { |i| create_test_sermon(@user, title: "Concurrent #{i}") }
    stub_video_generation_success

    assert_concurrent_performance(3, 15.seconds) do |index|
      post generate_video_path, params: { 
        sermon_id: sermons[index].id,
        video: @video_params
      }
    end

    perform_enqueued_jobs

    sermons.each(&:reload)
    sermons.each do |sermon|
      assert sermon.videos.any? { |v| v.status == "completed" }
    end
  end

  test "video generation retry mechanism" do
    # Simulate initial failure, then success on retry
    call_count = 0
    VideoGeneratorService.any_instance.stubs(:generate_video).returns(
      proc { 
        call_count += 1
        if call_count == 1
          OpenStruct.new(success?: false, error: "Temporary failure")
        else
          OpenStruct.new(success?: true, video_path: "/tmp/test.mp4", thumbnail_path: "/tmp/test.jpg")
        end
      }.call
    )

    @performance_tracker.track("Video Generation Retry") do
      post generate_video_path, params: { 
        sermon_id: @sermon.id,
        video: @video_params
      }
    end

    perform_enqueued_jobs

    @sermon.reload
    video = @sermon.videos.last
    assert_equal "completed", video.status
    assert_equal 2, call_count # Should have retried once
  end

  test "video generation memory management" do
    assert_memory_within(IntegrationTestHelper::PERFORMANCE_CONFIG[:max_memory_per_operation]) do
      stub_video_generation_success
      
      post generate_video_path, params: { 
        sermon_id: @sermon.id,
        video: @video_params
      }
      
      perform_enqueued_jobs
    end
  end

  test "video generation with custom templates" do
    templates = %w[minimal modern elegant classic spiritual]
    
    templates.each do |template|
      sermon = create_test_sermon(@user, title: "#{template.capitalize} Template Test")
      stub_video_generation_success

      post generate_video_path, params: { 
        sermon_id: sermon.id,
        video: @video_params.merge(template: template)
      }

      perform_enqueued_jobs
      
      sermon.reload
      video = sermon.videos.last
      assert_equal template, video.template
      assert_equal "completed", video.status
    end
  end

  test "video generation status updates" do
    video = create_test_video(@sermon, status: "pending")

    # Test status progression: pending -> processing -> completed
    statuses = %w[processing uploading completed]
    
    statuses.each do |status|
      @performance_tracker.track("Status Update to #{status}") do
        patch update_video_status_path(video), params: { status: status }
      end

      assert_response :success
      video.reload
      assert_equal status, video.status
    end
  end

  test "video generation dashboard" do
    create_sample_videos_for_user(@user, 10)

    @performance_tracker.track("Video Dashboard Load") do
      get videos_dashboard_path
    end

    assert_response :success
    assert_includes response.body, "Video Dashboard"
    assert_includes response.body, "10 videos"
    assert_includes response.body, "Generation Progress"
  end

  test "video generation analytics" do
    create_sample_videos_for_user(@user, 20)

    @performance_tracker.track("Video Analytics") do
      get video_analytics_path
    end

    assert_response :success
    assert_includes response.body, "Total Videos: 20"
    assert_includes response.body, "Success Rate"
    assert_includes response.body, "Average Generation Time"
  end

  test "video file cleanup after failure" do
    # Test that temporary files are cleaned up on failure
    stub_video_generation_failure

    post generate_video_path, params: { 
      sermon_id: @sermon.id,
      video: @video_params
    }

    perform_enqueued_jobs

    # Verify no temporary files remain
    temp_files = Dir.glob(Rails.root.join("tmp", "video_generation_*"))
    assert_empty temp_files, "Temporary files were not cleaned up"
  end

  private

  def create_authenticated_user
    oauth_data = {
      "provider" => "google_oauth2",
      "uid" => "123456789",
      "info" => {
        "email" => "test@example.com",
        "name" => "Test User"
      }
    }
    
    user = User.find_or_create_by_omniauth(oauth_data)
    sign_in_user(user)
    user
  end

  def sign_in_user(user)
    session[:user_id] = user.id
    session[:signed_in_at] = Time.current
  end

  def create_test_sermon(user, attributes = {})
    default_attributes = {
      title: "Test Sermon for Video",
      source_url: "https://test.com/sermon",
      church: "Test Church",
      pastor: "Test Pastor",
      scripture: "Test 1:1",
      interpretation: "This is test interpretation content for video generation testing.",
      action_points: "1. Test action point one. 2. Test action point two. 3. Test action point three.",
      denomination: "Test",
      sermon_date: 1.week.ago,
      audience_count: 100
    }

    Sermon.create!(default_attributes.merge(attributes))
  end

  def create_test_text_note(user, attributes = {})
    default_attributes = {
      title: "Test Text Note for Video",
      content: "This is test text note content for video generation testing.",
      note_type: "reflection",
      theme: "faith",
      user: user
    }

    TextNote.create!(default_attributes.merge(attributes))
  end

  def create_test_video(sermon, attributes = {})
    default_attributes = {
      sermon: sermon,
      script: "Test video script content",
      status: "pending",
      theme: "faith"
    }

    Video.create!(default_attributes.merge(attributes))
  end

  def create_sample_videos_for_user(user, count)
    count.times do |i|
      sermon = create_test_sermon(user, title: "Video Test Sermon #{i + 1}")
      create_test_video(sermon, 
        script: "Test script #{i + 1}",
        status: %w[pending processing completed failed].sample,
        theme: %w[faith hope love grace].sample
      )
    end
  end

  def generate_video_path
    "/videos/generate"
  end

  def generate_text_note_video_path
    "/text_notes/generate_video"
  end

  def batch_generate_videos_path
    "/videos/batch_generate"
  end

  def video_progress_path(video)
    "/videos/#{video.id}/progress"
  end

  def update_video_status_path(video)
    "/videos/#{video.id}/update_status"
  end

  def videos_dashboard_path
    "/videos/dashboard"
  end

  def video_analytics_path
    "/videos/analytics"
  end
end