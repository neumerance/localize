user = User.where('email=?', 'amir.helzer@onthegosoft.com').first

Project.transaction do
  project = Project.new(name: 'testproj', creation_time: Time.now)
  project.client = user
  project.save!

  revision = Revision.new(name: 'Initial', description: 'Simple test project', language_id: 1,
                          word_count: 100, max_bid: 1, max_bid_currency: 1,
                          bidding_duration: 10, project_completion_duration: 4,
                          release_date: Time.now, bidding_close_time: Time.now + 4 * DAY_IN_SECONDS,
                          released: 1)
  revision.project = project
  revision.save!
end
