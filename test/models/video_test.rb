require "test_helper"

class VideoTest < ActiveSupport::TestCase
  def setup
    @sermon = sermons(:one)
    @valid_video = Video.new(
      sermon: @sermon,
      script: "This is a comprehensive video script about faith and hope that meets minimum length requirements.",
      status: "pending"
    )
  end

  # Validation Tests
  test "should be valid with valid attributes" do
    assert @valid_video.valid?
  end

  test "should require script" do
    @valid_video.script = nil
    assert_not @valid_video.valid?
    assert_includes @valid_video.errors[:script], "can't be blank"
  end

  test "should require script minimum length of 10 characters" do
    @valid_video.script = "short"
    assert_not @valid_video.valid?
    assert_includes @valid_video.errors[:script], "is too short (minimum is 10 characters)"
  end

  test "should limit script to 10000 characters" do
    @valid_video.script = "a" * 10_001
    assert_not @valid_video.valid?
    assert_includes @valid_video.errors[:script], "is too long (maximum is 10000 characters)"
  end

  test "should require status" do
    @valid_video.status = nil
    assert_not @valid_video.valid?
    assert_includes @valid_video.errors[:status], "can't be blank"
  end

  test "should validate status inclusion" do
    @valid_video.status = "invalid_status"
    assert_not @valid_video.valid?
    assert_includes @valid_video.errors[:status], "is not included in the list"
  end

  test "should allow valid statuses" do
    %w[pending approved processing uploaded failed].each do |status|
      @valid_video.status = status
      assert @valid_video.valid?, "Should accept status: #{status}"
    end
  end

  test "should require unique youtube_id when present" do
    existing_video = Video.create!(@valid_video.attributes.merge(youtube_id: "ABC123"))
    duplicate_video = Video.new(@valid_video.attributes.merge(youtube_id: "ABC123"))
    
    assert_not duplicate_video.valid?
    assert_includes duplicate_video.errors[:youtube_id], "has already been taken"
  end

  test "should allow nil youtube_id" do
    @valid_video.youtube_id = nil
    assert @valid_video.valid?
  end

  test "should limit video_path to 500 characters" do
    @valid_video.video_path = "a" * 501
    assert_not @valid_video.valid?
    assert_includes @valid_video.errors[:video_path], "is too long (maximum is 500 characters)"
  end

  test "should limit thumbnail_path to 500 characters" do
    @valid_video.thumbnail_path = "a" * 501
    assert_not @valid_video.valid?
    assert_includes @valid_video.errors[:thumbnail_path], "is too long (maximum is 500 characters)"
  end

  # Association Tests
  test "should belong to sermon" do
    assert_respond_to @valid_video, :sermon
    assert_equal @sermon, @valid_video.sermon
  end

  test "should require sermon" do
    @valid_video.sermon = nil
    assert_not @valid_video.valid?
    assert_includes @valid_video.errors[:sermon], "must exist"
  end

  # Enum Tests
  test "should default to pending status" do
    video = Video.new
    assert_equal "pending", video.status
    assert video.pending?
  end

  test "should provide enum methods" do
    @valid_video.save!
    
    assert @valid_video.pending?
    assert_not @valid_video.approved?
    
    @valid_video.approved!
    assert @valid_video.approved?
    assert_not @valid_video.pending?
    
    @valid_video.processing!
    assert @valid_video.processing?
    
    @valid_video.uploaded!
    assert @valid_video.uploaded?
    
    @valid_video.failed!
    assert @valid_video.failed?
  end

  # Scope Tests
  test "recent scope should order by created_at desc" do
    old_video = Video.create!(@valid_video.attributes)
    sleep(0.01)
    new_video = Video.create!(@valid_video.attributes)
    
    recent_videos = Video.recent
    assert_equal new_video, recent_videos.first
    assert_equal old_video, recent_videos.last
  end

  test "with_youtube_id scope should include videos with youtube_id" do
    video_with_id = Video.create!(@valid_video.attributes.merge(youtube_id: "ABC123"))
    video_without_id = Video.create!(@valid_video.attributes)
    
    videos_with_id = Video.with_youtube_id
    assert_includes videos_with_id, video_with_id
    assert_not_includes videos_with_id, video_without_id
  end

  test "without_youtube_id scope should include videos without youtube_id" do
    video_with_id = Video.create!(@valid_video.attributes.merge(youtube_id: "ABC123"))
    video_without_id = Video.create!(@valid_video.attributes)
    
    videos_without_id = Video.without_youtube_id
    assert_not_includes videos_without_id, video_with_id
    assert_includes videos_without_id, video_without_id
  end

  test "ready_for_processing scope should include approved videos without video_path" do
    ready_video = Video.create!(@valid_video.attributes.merge(status: "approved"))
    not_ready_video = Video.create!(@valid_video.attributes.merge(
      status: "approved",
      video_path: "/path/to/video.mp4"
    ))
    pending_video = Video.create!(@valid_video.attributes.merge(status: "pending"))
    
    ready_videos = Video.ready_for_processing
    assert_includes ready_videos, ready_video
    assert_not_includes ready_videos, not_ready_video
    assert_not_includes ready_videos, pending_video
  end

  test "ready_for_upload scope should include processing videos with video_path" do
    ready_video = Video.create!(@valid_video.attributes.merge(
      status: "processing",
      video_path: "/path/to/video.mp4"
    ))
    not_ready_video = Video.create!(@valid_video.attributes.merge(status: "processing"))
    wrong_status_video = Video.create!(@valid_video.attributes.merge(
      status: "approved",
      video_path: "/path/to/video.mp4"
    ))
    
    ready_videos = Video.ready_for_upload
    assert_includes ready_videos, ready_video
    assert_not_includes ready_videos, not_ready_video
    assert_not_includes ready_videos, wrong_status_video
  end

  # State Machine Method Tests
  test "can_approve should return true for pending videos" do
    @valid_video.status = "pending"
    assert @valid_video.can_approve?
    
    @valid_video.status = "approved"
    assert_not @valid_video.can_approve?
  end

  test "can_reject should return true for pending or approved videos" do
    @valid_video.status = "pending"
    assert @valid_video.can_reject?
    
    @valid_video.status = "approved"
    assert @valid_video.can_reject?
    
    @valid_video.status = "processing"
    assert_not @valid_video.can_reject?
  end

  test "can_process should return true for approved videos" do
    @valid_video.status = "approved"
    assert @valid_video.can_process?
    
    @valid_video.status = "pending"
    assert_not @valid_video.can_process?
  end

  test "can_upload should return true for processing videos with video_path" do
    @valid_video.status = "processing"
    @valid_video.video_path = "/path/to/video.mp4"
    assert @valid_video.can_upload?
    
    @valid_video.video_path = nil
    assert_not @valid_video.can_upload?
    
    @valid_video.status = "approved"
    @valid_video.video_path = "/path/to/video.mp4"
    assert_not @valid_video.can_upload?
  end

  test "approve! should transition from pending to approved" do
    @valid_video.save!
    assert @valid_video.pending?
    
    @valid_video.approve!
    assert @valid_video.approved?
  end

  test "reject! should transition to failed status" do
    @valid_video.save!
    @valid_video.reject!
    assert @valid_video.failed?
  end

  test "start_processing! should transition to processing status" do
    @valid_video.status = "approved"
    @valid_video.save!
    
    @valid_video.start_processing!
    assert @valid_video.processing?
  end

  test "complete_upload! should transition to uploaded status and set youtube_id" do
    @valid_video.status = "processing"
    @valid_video.save!
    
    youtube_id = "ABC123XYZ"
    @valid_video.complete_upload!(youtube_id)
    
    assert @valid_video.uploaded?
    assert_equal youtube_id, @valid_video.youtube_id
  end

  # File Management Tests
  test "video_file_size should return file size when video_path exists" do
    @valid_video.video_path = Rails.root.join('tmp', 'test_video.mp4').to_s
    
    # Create a test file
    File.write(@valid_video.video_path, "test video content")
    
    expected_size = File.size(@valid_video.video_path)
    assert_equal expected_size, @valid_video.video_file_size
    
    # Cleanup
    File.delete(@valid_video.video_path)
  end

  test "video_file_size should return nil when video_path is nil" do
    @valid_video.video_path = nil
    assert_nil @valid_video.video_file_size
  end

  test "video_file_size should return nil when file does not exist" do
    @valid_video.video_path = "/nonexistent/path.mp4"
    assert_nil @valid_video.video_file_size
  end

  test "has_thumbnail? should return true when thumbnail_path is present" do
    @valid_video.thumbnail_path = "/path/to/thumbnail.jpg"
    assert @valid_video.has_thumbnail?
    
    @valid_video.thumbnail_path = nil
    assert_not @valid_video.has_thumbnail?
  end

  # Callback Tests
  test "should sanitize script before save" do
    @valid_video.script = "  <script>alert('xss')</script>  This is a test script with malicious content.  "
    @valid_video.save!
    
    assert_not_includes @valid_video.script, "<script>"
    assert_not_includes @valid_video.script, "alert"
    assert_includes @valid_video.script, "This is a test script"
    refute @valid_video.script.starts_with?(" ")
    refute @valid_video.script.ends_with?(" ")
  end

  test "should log status change after update" do
    @valid_video.save!
    
    Rails.logger.expects(:info).with(regexp_matches(/Video.*status changed/))
    @valid_video.update!(status: "approved")
  end

  test "should cleanup files before destroy" do
    test_video_path = Rails.root.join('tmp', 'test_video_cleanup.mp4').to_s
    test_thumbnail_path = Rails.root.join('tmp', 'test_thumbnail_cleanup.jpg').to_s
    
    # Create test files
    File.write(test_video_path, "test video")
    File.write(test_thumbnail_path, "test thumbnail")
    
    @valid_video.video_path = test_video_path
    @valid_video.thumbnail_path = test_thumbnail_path
    @valid_video.save!
    
    # Verify files exist
    assert File.exist?(test_video_path)
    assert File.exist?(test_thumbnail_path)
    
    # Destroy video
    @valid_video.destroy
    
    # Verify files are cleaned up
    assert_not File.exist?(test_video_path)
    assert_not File.exist?(test_thumbnail_path)
  end

  # Edge Cases and Security Tests
  test "should handle malicious script content" do
    malicious_scripts = [
      "<script>alert('xss')</script>",
      "javascript:alert('xss')",
      "<iframe src='javascript:alert(1)'></iframe>",
      "<img onerror='alert(1)' src='x'>"
    ]
    
    malicious_scripts.each do |script|
      @valid_video.script = script + " This is valid content for testing."
      @valid_video.save!
      
      assert_not_includes @valid_video.script, "<script>"
      assert_not_includes @valid_video.script, "javascript:"
      assert_not_includes @valid_video.script, "<iframe"
      assert_not_includes @valid_video.script, "onerror"
    end
  end

  test "should handle special characters in script" do
    @valid_video.script = "Faith & Hope: God's Plan (Part 1) with 'quotes' and \"double quotes\""
    assert @valid_video.valid?
  end

  test "should handle unicode characters in script" do
    @valid_video.script = "신앙과 희망 - Korean text about faith and hope"
    assert @valid_video.valid?
  end

  test "should handle file paths with special characters" do
    @valid_video.video_path = "/path/to/video with spaces & symbols.mp4"
    @valid_video.thumbnail_path = "/path/to/thumbnail (1).jpg"
    assert @valid_video.valid?
  end

  test "should handle concurrent status updates" do
    @valid_video.save!
    
    # Simulate concurrent updates
    video1 = Video.find(@valid_video.id)
    video2 = Video.find(@valid_video.id)
    
    video1.update!(status: "approved")
    video2.reload
    
    assert_equal "approved", video2.status
  end

  test "should handle large script content" do
    large_script = "This is a test script. " * 400 # ~9600 characters
    @valid_video.script = large_script
    assert @valid_video.valid?
    
    too_large_script = "This is a test script. " * 500 # ~12000 characters
    @valid_video.script = too_large_script
    assert_not @valid_video.valid?
  end
end
