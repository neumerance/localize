class Chat < ApplicationRecord
  belongs_to :revision
  belongs_to :translator, touch: true

  has_many :reminders, as: :owner, dependent: :destroy
  has_many :messages, as: :owner, dependent: :destroy
  has_many :bids, dependent: :destroy
  has_many :revision_languages, -> { where(bids: { status: BID_ACCEPTED_STATUSES }) }, through: :bids

  has_one :support_ticket, as: :object, dependent: :destroy

  include Trackable
  include ParentWithSiblings
  # before_save :count_track
  #

  def revision_language_for(language_name)
    revision_languages.to_a.find { |rev_lang| rev_lang.language.name == language_name }
  end

  def delete_reminders(who)
    reminders.where(normal_user_id: who.id).find_each(&:destroy)
  end

  def translator_can_access
    # translator_has_access is always 0 for website translation projects
    if translator_has_access == 1
      true
    else
      has_accepted_bid
    end
  end

  def accepted_bid
    bids.where(status: BID_ACCEPTED_STATUSES).first
  end

  def has_accepted_bid
    accepted_bid.present?
  end

  def user_can_post
    # A user can post if the review is open to bids or no other translator got the job
    (revision.open_to_bids == 1) || !bids.empty?
  end

  def count_track
    tracks = ChatTrack.where('resource_id = ?', id)
    update_track(tracks)

    update_track_by_user([translator_id, revision.project.client_id])

  end

  def chat_languages
    unless @chat_languages_cache
      @chat_languages_cache = revision_languages.collect do |rl|
        [rl.language] +
          (rl.selected_bid ? [rl.selected_bid.status, rl.selected_bid.id] : [BID_TERMINATED, nil]) +
          (rl.managed_work ? [rl.managed_work.translation_status] : [nil])
      end
    end

    @chat_languages_cache
  end

  def track_hierarchy(user_session, recursive = true)
    track = ChatTrack.new(resource_id: id)
    # seperated to two questions to make sure the add_track gets executed
    if add_track(track, user_session)
      revision.track_hierarchy(user_session, recursive) if recursive && revision
    end
  end

  def track_with_siblings(user_session, _recursive = true)
    track = ChatTrack.new(resource_id: id)
    add_track(track, user_session)
  end

  # return list of siblings
  def siblings
    messages
  end

  def can_delete_me
    messages.empty? && bids.empty?
  end

end
