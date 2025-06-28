class AddPerformanceIndexes < ActiveRecord::Migration[8.0]
  def change
    # Indexes for Sermon search performance
    add_index :sermons, :title, name: 'index_sermons_on_title'
    add_index :sermons, :pastor, name: 'index_sermons_on_pastor'
    add_index :sermons, :scripture, name: 'index_sermons_on_scripture'
    add_index :sermons, :church, name: 'index_sermons_on_church'
    add_index :sermons, :denomination, name: 'index_sermons_on_denomination'
    add_index :sermons, :created_at, name: 'index_sermons_on_created_at'
    
    # Composite index for recent sermons (used in dashboard)
    add_index :sermons, [:created_at, :id], name: 'index_sermons_on_created_at_and_id'
    
    # Indexes for Video status-based queries
    add_index :videos, :status, name: 'index_videos_on_status'
    add_index :videos, :youtube_id, name: 'index_videos_on_youtube_id'
    add_index :videos, :created_at, name: 'index_videos_on_created_at'
    
    # Composite indexes for video processing
    add_index :videos, [:status, :created_at], name: 'index_videos_on_status_and_created_at'
    add_index :videos, [:sermon_id, :status], name: 'index_videos_on_sermon_id_and_status'
    
    # Foreign key indexes for join performance (check if exists first)
    add_index :videos, :sermon_id, name: 'index_videos_on_sermon_id' unless index_exists?(:videos, :sermon_id)
    
    # Full-text search index for sermon content (if using PostgreSQL in future)
    # add_index :sermons, "to_tsvector('english', coalesce(title, '') || ' ' || coalesce(interpretation, '') || ' ' || coalesce(pastor, ''))", 
    #           using: :gin, name: 'index_sermons_on_search_content'
  end
end
