require "test_helper"

class SermonTest < ActiveSupport::TestCase
  def setup
    @valid_sermon = Sermon.new(
      title: "Faith and Hope in Difficult Times",
      source_url: "https://example-church.com/sermons/faith-hope",
      church: "Grace Community Church",
      pastor: "Pastor John Smith",
      scripture: "Romans 8:28",
      interpretation: "God works all things together for good",
      action_points: "Trust in God's plan, pray daily, serve others",
      denomination: "Baptist",
      sermon_date: 1.week.ago,
      audience_count: 150
    )
  end

  # Validation Tests
  test "should be valid with valid attributes" do
    assert @valid_sermon.valid?
  end

  test "should require title" do
    @valid_sermon.title = nil
    assert_not @valid_sermon.valid?
    assert_includes @valid_sermon.errors[:title], "can't be blank"
  end

  test "should require title to be under 255 characters" do
    @valid_sermon.title = "a" * 256
    assert_not @valid_sermon.valid?
    assert_includes @valid_sermon.errors[:title], "is too long (maximum is 255 characters)"
  end

  test "should require source_url" do
    @valid_sermon.source_url = nil
    assert_not @valid_sermon.valid?
    assert_includes @valid_sermon.errors[:source_url], "can't be blank"
  end

  test "should require valid URL format for source_url" do
    @valid_sermon.source_url = "invalid-url"
    assert_not @valid_sermon.valid?
    assert_includes @valid_sermon.errors[:source_url], "is invalid"
  end

  test "should require unique source_url" do
    @valid_sermon.save!
    duplicate_sermon = @valid_sermon.dup
    assert_not duplicate_sermon.valid?
    assert_includes duplicate_sermon.errors[:source_url], "has already been taken"
  end

  test "should require church" do
    @valid_sermon.church = nil
    assert_not @valid_sermon.valid?
    assert_includes @valid_sermon.errors[:church], "can't be blank"
  end

  test "should limit church name to 100 characters" do
    @valid_sermon.church = "a" * 101
    assert_not @valid_sermon.valid?
    assert_includes @valid_sermon.errors[:church], "is too long (maximum is 100 characters)"
  end

  test "should limit pastor name to 100 characters" do
    @valid_sermon.pastor = "a" * 101
    assert_not @valid_sermon.valid?
    assert_includes @valid_sermon.errors[:pastor], "is too long (maximum is 100 characters)"
  end

  test "should limit scripture to 1000 characters" do
    @valid_sermon.scripture = "a" * 1001
    assert_not @valid_sermon.valid?
    assert_includes @valid_sermon.errors[:scripture], "is too long (maximum is 1000 characters)"
  end

  test "should limit interpretation to 5000 characters" do
    @valid_sermon.interpretation = "a" * 5001
    assert_not @valid_sermon.valid?
    assert_includes @valid_sermon.errors[:interpretation], "is too long (maximum is 5000 characters)"
  end

  test "should limit action_points to 2000 characters" do
    @valid_sermon.action_points = "a" * 2001
    assert_not @valid_sermon.valid?
    assert_includes @valid_sermon.errors[:action_points], "is too long (maximum is 2000 characters)"
  end

  test "should limit denomination to 50 characters" do
    @valid_sermon.denomination = "a" * 51
    assert_not @valid_sermon.valid?
    assert_includes @valid_sermon.errors[:denomination], "is too long (maximum is 50 characters)"
  end

  test "should require positive audience_count" do
    @valid_sermon.audience_count = 0
    assert_not @valid_sermon.valid?
    assert_includes @valid_sermon.errors[:audience_count], "must be greater than 0"
    
    @valid_sermon.audience_count = -1
    assert_not @valid_sermon.valid?
    assert_includes @valid_sermon.errors[:audience_count], "must be greater than 0"
  end

  test "should allow nil audience_count" do
    @valid_sermon.audience_count = nil
    assert @valid_sermon.valid?
  end

  # Association Tests
  test "should have many videos" do
    @valid_sermon.save!
    video1 = @valid_sermon.videos.create!(script: "Test script 1", status: "pending")
    video2 = @valid_sermon.videos.create!(script: "Test script 2", status: "processing")
    
    assert_equal 2, @valid_sermon.videos.count
    assert_includes @valid_sermon.videos, video1
    assert_includes @valid_sermon.videos, video2
  end

  test "should destroy associated videos when sermon is destroyed" do
    @valid_sermon.save!
    video = @valid_sermon.videos.create!(script: "Test script", status: "pending")
    video_id = video.id
    
    @valid_sermon.destroy
    assert_raises(ActiveRecord::RecordNotFound) { Video.find(video_id) }
  end

  # Scope Tests
  test "recent scope should order by created_at desc" do
    old_sermon = Sermon.create!(@valid_sermon.attributes.merge(source_url: "https://old.com"))
    sleep(0.01) # Ensure different timestamps
    new_sermon = Sermon.create!(@valid_sermon.attributes.merge(source_url: "https://new.com"))
    
    recent_sermons = Sermon.recent
    assert_equal new_sermon, recent_sermons.first
    assert_equal old_sermon, recent_sermons.last
  end

  test "by_date scope should order by sermon_date desc" do
    old_sermon = Sermon.create!(@valid_sermon.attributes.merge(
      source_url: "https://old.com",
      sermon_date: 2.weeks.ago
    ))
    new_sermon = Sermon.create!(@valid_sermon.attributes.merge(
      source_url: "https://new.com",
      sermon_date: 1.week.ago
    ))
    
    by_date_sermons = Sermon.by_date
    assert_equal new_sermon, by_date_sermons.first
    assert_equal old_sermon, by_date_sermons.last
  end

  test "by_church scope should filter by church name" do
    church_a_sermon = Sermon.create!(@valid_sermon.attributes.merge(
      source_url: "https://church-a.com",
      church: "Church A"
    ))
    church_b_sermon = Sermon.create!(@valid_sermon.attributes.merge(
      source_url: "https://church-b.com",
      church: "Church B"
    ))
    
    church_a_sermons = Sermon.by_church("Church A")
    assert_includes church_a_sermons, church_a_sermon
    assert_not_includes church_a_sermons, church_b_sermon
  end

  test "by_pastor scope should filter by pastor name" do
    pastor_a_sermon = Sermon.create!(@valid_sermon.attributes.merge(
      source_url: "https://pastor-a.com",
      pastor: "Pastor A"
    ))
    pastor_b_sermon = Sermon.create!(@valid_sermon.attributes.merge(
      source_url: "https://pastor-b.com",
      pastor: "Pastor B"
    ))
    
    pastor_a_sermons = Sermon.by_pastor("Pastor A")
    assert_includes pastor_a_sermons, pastor_a_sermon
    assert_not_includes pastor_a_sermons, pastor_b_sermon
  end

  test "by_denomination scope should filter by denomination" do
    baptist_sermon = Sermon.create!(@valid_sermon.attributes.merge(
      source_url: "https://baptist.com",
      denomination: "Baptist"
    ))
    methodist_sermon = Sermon.create!(@valid_sermon.attributes.merge(
      source_url: "https://methodist.com",
      denomination: "Methodist"
    ))
    
    baptist_sermons = Sermon.by_denomination("Baptist")
    assert_includes baptist_sermons, baptist_sermon
    assert_not_includes baptist_sermons, methodist_sermon
  end

  test "with_videos scope should include sermons that have videos" do
    sermon_with_video = Sermon.create!(@valid_sermon.attributes)
    sermon_with_video.videos.create!(script: "Test", status: "pending")
    
    sermon_without_video = Sermon.create!(@valid_sermon.attributes.merge(
      source_url: "https://no-video.com"
    ))
    
    sermons_with_videos = Sermon.with_videos
    assert_includes sermons_with_videos, sermon_with_video
    assert_not_includes sermons_with_videos, sermon_without_video
  end

  test "without_videos scope should include sermons that have no videos" do
    sermon_with_video = Sermon.create!(@valid_sermon.attributes)
    sermon_with_video.videos.create!(script: "Test", status: "pending")
    
    sermon_without_video = Sermon.create!(@valid_sermon.attributes.merge(
      source_url: "https://no-video.com"
    ))
    
    sermons_without_videos = Sermon.without_videos
    assert_not_includes sermons_without_videos, sermon_with_video
    assert_includes sermons_without_videos, sermon_without_video
  end

  # Business Logic Tests
  test "display_date should return formatted sermon_date or created_at" do
    sermon_with_date = Sermon.create!(@valid_sermon.attributes.merge(
      sermon_date: Date.new(2023, 12, 25)
    ))
    assert_equal "December 25, 2023", sermon_with_date.display_date
    
    sermon_without_date = Sermon.create!(@valid_sermon.attributes.merge(
      source_url: "https://no-date.com",
      sermon_date: nil
    ))
    expected_date = sermon_without_date.created_at.strftime("%B %d, %Y")
    assert_equal expected_date, sermon_without_date.display_date
  end

  test "short_description should truncate interpretation to 150 characters" do
    long_interpretation = "a" * 200
    sermon = Sermon.create!(@valid_sermon.attributes.merge(
      interpretation: long_interpretation
    ))
    assert_equal 150, sermon.short_description.length
    assert sermon.short_description.ends_with?("...")
    
    short_interpretation = "Short text"
    sermon.update!(interpretation: short_interpretation)
    assert_equal short_interpretation, sermon.short_description
  end

  test "search should find sermons by title, pastor, or church" do
    sermon1 = Sermon.create!(@valid_sermon.attributes.merge(
      title: "Amazing Grace",
      pastor: "John Wesley",
      church: "Methodist Central"
    ))
    sermon2 = Sermon.create!(@valid_sermon.attributes.merge(
      source_url: "https://different.com",
      title: "Faith Journey",
      pastor: "Billy Graham",
      church: "Baptist Fellowship"
    ))
    
    # Search by title
    results = Sermon.search("Amazing")
    assert_includes results, sermon1
    assert_not_includes results, sermon2
    
    # Search by pastor
    results = Sermon.search("Wesley")
    assert_includes results, sermon1
    assert_not_includes results, sermon2
    
    # Search by church
    results = Sermon.search("Methodist")
    assert_includes results, sermon1
    assert_not_includes results, sermon2
    
    # Case insensitive search
    results = Sermon.search("amazing")
    assert_includes results, sermon1
  end

  # Callback Tests
  test "should normalize fields before save" do
    sermon = Sermon.new(@valid_sermon.attributes.merge(
      church: "  GRACE CHURCH  ",
      pastor: "  pastor john  ",
      denomination: "  BAPTIST  "
    ))
    sermon.save!
    
    assert_equal "Grace Church", sermon.church
    assert_equal "Pastor John", sermon.pastor
    assert_equal "Baptist", sermon.denomination
  end

  test "should log creation after create" do
    assert_difference 'Rails.logger.info.call_count', 1 do
      Rails.logger.expects(:info).with(regexp_matches(/Sermon created/))
      @valid_sermon.save!
    end
  end

  # Edge Cases and Security Tests
  test "should handle malicious URL patterns" do
    malicious_urls = [
      "javascript:alert('xss')",
      "data:text/html,<script>alert('xss')</script>",
      "file:///etc/passwd",
      "ftp://malicious.com"
    ]
    
    malicious_urls.each do |url|
      @valid_sermon.source_url = url
      assert_not @valid_sermon.valid?, "Should reject malicious URL: #{url}"
    end
  end

  test "should handle extremely long valid URLs" do
    long_url = "https://example.com/" + ("a" * 2000)
    @valid_sermon.source_url = long_url
    assert @valid_sermon.valid?, "Should accept long but valid URLs"
  end

  test "should handle special characters in text fields" do
    @valid_sermon.title = "Faith & Hope: God's Plan (Part 1)"
    @valid_sermon.scripture = "Matthew 5:3-12; Luke 6:20-23"
    @valid_sermon.interpretation = "Text with 'quotes' and \"double quotes\" and symbols: @#$%"
    assert @valid_sermon.valid?
  end

  test "should handle unicode characters" do
    @valid_sermon.title = "신앙과 희망" # Korean text
    @valid_sermon.pastor = "José María" # Spanish with accents
    @valid_sermon.church = "Église de la Grâce" # French with accents
    assert @valid_sermon.valid?
  end
end
