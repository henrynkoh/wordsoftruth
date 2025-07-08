# frozen_string_literal: true

require "test_helper"

class TextNotesCrudTest < ActionDispatch::IntegrationTest
  def setup
    super
    @user = create_authenticated_user
    @text_note_params = {
      title: "Test Spiritual Note",
      content: "This is a test spiritual reflection about faith and hope in difficult times.",
      note_type: "reflection",
      visibility: "private"
    }
  end

  test "user can view text notes index" do
    create_sample_text_notes_for_user(@user, 5)

    @performance_tracker.track("Text Notes Index") do
      get text_notes_path
    end

    assert_response :success
    assert_includes response.body, "Text Notes"
    assert_includes response.body, "Test Note"
    assert_response_includes "5 notes"
  end

  test "user can create new text note" do
    @performance_tracker.track("Text Note Creation") do
      get new_text_note_path
    end

    assert_response :success
    assert_includes response.body, "New Text Note"

    assert_difference "TextNote.count", 1 do
      @performance_tracker.track("Text Note Save") do
        post text_notes_path, params: { text_note: @text_note_params }
      end
    end

    assert_response :redirect
    text_note = TextNote.last
    assert_equal @text_note_params[:title], text_note.title
    assert_equal @text_note_params[:content], text_note.content
    assert_equal @user.id, text_note.user_id
    assert_equal "pending", text_note.status

    follow_redirect!
    assert_response :success
    assert_includes response.body, "Text note created successfully"
  end

  test "user can view individual text note" do
    text_note = create_text_note_for_user(@user, @text_note_params)

    @performance_tracker.track("Text Note Show") do
      get text_note_path(text_note)
    end

    assert_response :success
    assert_includes response.body, text_note.title
    assert_includes response.body, text_note.content
    assert_includes response.body, "reflection"
  end

  test "user can edit text note" do
    text_note = create_text_note_for_user(@user, @text_note_params)

    @performance_tracker.track("Text Note Edit Form") do
      get edit_text_note_path(text_note)
    end

    assert_response :success
    assert_includes response.body, "Edit Text Note"
    assert_includes response.body, text_note.title

    updated_params = @text_note_params.merge(title: "Updated Spiritual Note")

    @performance_tracker.track("Text Note Update") do
      patch text_note_path(text_note), params: { text_note: updated_params }
    end

    assert_response :redirect
    text_note.reload
    assert_equal "Updated Spiritual Note", text_note.title

    follow_redirect!
    assert_includes response.body, "Text note updated successfully"
  end

  test "user can delete text note" do
    text_note = create_text_note_for_user(@user, @text_note_params)

    assert_difference "TextNote.count", -1 do
      @performance_tracker.track("Text Note Deletion") do
        delete text_note_path(text_note)
      end
    end

    assert_response :redirect
    assert_redirected_to text_notes_path

    follow_redirect!
    assert_includes response.body, "Text note deleted successfully"
  end

  test "user cannot access other users' text notes" do
    other_user = create_user_with_oauth("other@example.com")
    other_text_note = create_text_note_for_user(other_user, @text_note_params)

    @performance_tracker.track("Unauthorized Access Attempt") do
      get text_note_path(other_text_note)
    end

    assert_response :not_found
  end

  test "text note creation with AI theme detection" do
    spiritual_content = "In times of trial, we must remember that God's grace is sufficient for us. His love never fails, and His mercy is new every morning."
    
    params = @text_note_params.merge(content: spiritual_content)

    assert_difference "TextNote.count", 1 do
      @performance_tracker.track("AI Theme Detection") do
        post text_notes_path, params: { text_note: params }
      end
    end

    text_note = TextNote.last
    assert_not_nil text_note.theme
    assert_includes %w[grace mercy love faith hope trust], text_note.theme
  end

  test "text note creation triggers video generation job" do
    assert_enqueued_with(job: TextNoteVideoJob) do
      @performance_tracker.track("Video Job Enqueue") do
        post text_notes_path, params: { text_note: @text_note_params }
      end
    end

    text_note = TextNote.last
    assert_equal "pending", text_note.status
  end

  test "text note validation prevents malicious content" do
    malicious_params = @text_note_params.merge(
      title: "<script>alert('xss')</script>",
      content: "'; DROP TABLE text_notes; --"
    )

    assert_no_difference "TextNote.count" do
      post text_notes_path, params: { text_note: malicious_params }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "contains potentially malicious content"
  end

  test "text note creation with Korean content" do
    korean_params = @text_note_params.merge(
      title: "한국어 제목",
      content: "하나님의 사랑은 영원합니다. 우리는 어려운 시기에도 믿음을 가지고 살아갑니다."
    )

    assert_difference "TextNote.count", 1 do
      @performance_tracker.track("Korean Content Creation") do
        post text_notes_path, params: { text_note: korean_params }
      end
    end

    text_note = TextNote.last
    assert_equal korean_params[:title], text_note.title
    assert_equal korean_params[:content], text_note.content
  end

  test "text note bulk operations" do
    create_sample_text_notes_for_user(@user, 10)

    @performance_tracker.track("Bulk Delete") do
      text_note_ids = @user.text_notes.limit(5).pluck(:id)
      delete bulk_delete_text_notes_path, params: { text_note_ids: text_note_ids }
    end

    assert_response :redirect
    assert_equal 5, @user.text_notes.count
    
    follow_redirect!
    assert_includes response.body, "5 text notes deleted"
  end

  test "text note search functionality" do
    create_text_note_for_user(@user, title: "Faith in Action", content: "Living out our faith")
    create_text_note_for_user(@user, title: "Hope Springs Eternal", content: "Never lose hope")
    create_text_note_for_user(@user, title: "Love Conquers All", content: "The power of love")

    @performance_tracker.track("Text Note Search") do
      get text_notes_path, params: { search: "faith" }
    end

    assert_response :success
    assert_includes response.body, "Faith in Action"
    assert_not_includes response.body, "Hope Springs Eternal"
    assert_not_includes response.body, "Love Conquers All"
  end

  test "text note pagination" do
    create_sample_text_notes_for_user(@user, 25)

    @performance_tracker.track("Paginated Index") do
      get text_notes_path, params: { page: 2 }
    end

    assert_response :success
    assert_includes response.body, "Page 2"
    assert_includes response.body, "Previous"
  end

  test "text note filtering by theme" do
    create_text_note_for_user(@user, theme: "faith")
    create_text_note_for_user(@user, theme: "hope")
    create_text_note_for_user(@user, theme: "love")

    @performance_tracker.track("Theme Filter") do
      get text_notes_path, params: { theme: "faith" }
    end

    assert_response :success
    assert_response_includes "faith"
    assert_response_excludes "hope"
    assert_response_excludes "love"
  end

  test "text note export functionality" do
    create_sample_text_notes_for_user(@user, 5)

    @performance_tracker.track("Export Notes") do
      get export_text_notes_path, params: { format: "json" }
    end

    assert_response :success
    assert_equal "application/json", response.content_type
    
    json_data = JSON.parse(response.body)
    assert_equal 5, json_data["text_notes"].count
    assert json_data["exported_at"]
  end

  test "text note status updates" do
    text_note = create_text_note_for_user(@user, @text_note_params)
    
    @performance_tracker.track("Status Update") do
      patch update_status_text_note_path(text_note), params: { status: "processing" }
    end

    assert_response :success
    text_note.reload
    assert_equal "processing", text_note.status
  end

  test "text note duplicate prevention" do
    create_text_note_for_user(@user, @text_note_params)

    # Try to create identical note
    assert_no_difference "TextNote.count" do
      post text_notes_path, params: { text_note: @text_note_params }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "Similar note already exists"
  end

  test "text note concurrent editing" do
    text_note = create_text_note_for_user(@user, @text_note_params)
    
    # Simulate concurrent edits
    assert_concurrent_performance(3, 5.seconds) do |user_index|
      patch text_note_path(text_note), params: { 
        text_note: { title: "Concurrent Edit #{user_index}" }
      }
    end

    text_note.reload
    assert_includes text_note.title, "Concurrent Edit"
  end

  test "text note API endpoints" do
    text_note = create_text_note_for_user(@user, @text_note_params)

    @performance_tracker.track("API Index") do
      get api_text_notes_path, headers: { "Accept" => "application/json" }
    end

    assert_response :success
    assert_equal "application/json", response.content_type
    
    json_data = JSON.parse(response.body)
    assert json_data["text_notes"].is_a?(Array)
    assert_equal 1, json_data["text_notes"].count
  end

  test "text note performance meets requirements" do
    assert_performance_within(IntegrationTestHelper::PERFORMANCE_CONFIG[:dashboard_response]) do
      get text_notes_path
    end

    assert_performance_within(IntegrationTestHelper::PERFORMANCE_CONFIG[:api_response]) do
      post text_notes_path, params: { text_note: @text_note_params }
    end
  end

  test "text note memory usage is reasonable" do
    assert_memory_within(IntegrationTestHelper::PERFORMANCE_CONFIG[:max_memory_per_operation]) do
      create_sample_text_notes_for_user(@user, 10)
      get text_notes_path
    end
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

  def create_user_with_oauth(email)
    oauth_data = {
      "provider" => "google_oauth2",
      "uid" => SecureRandom.hex(8),
      "info" => {
        "email" => email,
        "name" => "Other User"
      }
    }
    
    User.find_or_create_by_omniauth(oauth_data)
  end

  def sign_in_user(user)
    # Mock session for testing
    session[:user_id] = user.id
    session[:signed_in_at] = Time.current
  end

  def create_text_note_for_user(user, params)
    TextNote.create!(params.merge(user: user))
  end

  def create_sample_text_notes_for_user(user, count)
    count.times do |i|
      create_text_note_for_user(user, 
        title: "Test Note #{i + 1}",
        content: "This is test content for note #{i + 1}",
        note_type: "reflection",
        theme: %w[faith hope love grace mercy].sample
      )
    end
  end

  def api_text_notes_path
    "/api/text_notes"
  end

  def export_text_notes_path
    "/text_notes/export"
  end

  def update_status_text_note_path(text_note)
    "/text_notes/#{text_note.id}/update_status"
  end

  def bulk_delete_text_notes_path
    "/text_notes/bulk_delete"
  end
end