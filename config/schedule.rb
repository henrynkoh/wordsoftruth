# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
#
# set :output, "/path/to/my/cron_log.log"
#
# every 2.hours do
#   command "/usr/bin/some_great_command"
#   runner "MyModel.some_method"
#   rake "some:great:rake:task"
# end
#
# every 4.days do
#   runner "AnotherModel.prune_old_records"
# end

# Learn more: http://github.com/javan/whenever

set :output, "log/cron.log"
env :PATH, ENV['PATH']

# Crawl sermons three times a week (Monday, Thursday, Sunday at 6 AM)
every '0 6 * * 1,4,7' do
  runner "SermonCrawlingJob.perform_later"
end

# Process approved videos every hour
every 1.hour do
  runner "Video.approved.find_each { |video| VideoProcessingJob.perform_later(video.id) }"
end

# Clean up temporary files daily at midnight
every :day, at: '00:00' do
  command "rm -rf #{Rails.root.join('tmp', 'videos')}/*"
end 