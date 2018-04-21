#   kind:
#     0: TA_PROJECT # From TA
#     1: MANUAL_PROJECT # H&M
#     2: SIS_PROJECT # sisulizer file project
#
#   source:
#     0: Static website
#     1: MANUAL_PROJECT # H & M
class Project < ApplicationRecord
  if Rails.env.production?
    acts_as_ferret(fields: [:name],
                   index_dir: "#{FERRET_INDEX_DIR}/project",
                   remote: true)
  end

  validates :name, presence: true, uniqueness: true

  has_many :support_files, foreign_key: :owner_id, dependent: :destroy
  has_many :revisions, dependent: :destroy
  belongs_to :client
  belongs_to :alias

  include Trackable
  include ParentWithSiblings
  # before_save :count_track

  def can_create_new_revisions
    return [true, nil] if revisions.empty?

    for revision in revisions.reverse
      if revision.cms_request
        return [true, nil]
      elsif revision.has_active_bids
        return [false, revision]
      end
    end
    [true, nil]
  end

  def count_track
    tracks = ProjectTrack.where(resource_id: id)
    update_track(tracks)
  end

  def track_hierarchy(user_session, _recursive = true)
    track = ProjectTrack.new(resource_id: id)
    add_track(track, user_session)
  end

  def track_with_siblings(user_session, recursive = true)
    track = ProjectTrack.new(resource_id: id)
    add_track(track, user_session)
    if recursive
      unless revisions.empty?
        revisions[-1].track_with_siblings(user_session, recursive)
      end
    end
  end

  # return list of siblings
  def siblings
    revisions + support_files
  end

  # -- old unused call -- a project can always be deleted. The problem may be with its children
  def can_delete_me
    true
  end

  def not_last_revision?(revision)
    (revisions.count > 1) && (revisions[-1] != revision)
  end

  def print_type
    kind == TA_PROJECT ? 'Website translation' : 'General (non-website) translation'
  end

  def is_from_website?
    revisions.try(:first).try(:cms_request) ||
      CmsTerm.where(['kind = ? and txt like ?', 'private_key', "%#{private_key}"]).first
  end

  def website
    return nil unless is_from_website?
    if revisions.try(:first).try(:cms_request)
      revisions.first.cms_request.website
    else
      CmsTerm.where(['kind = ? and txt like ?', 'private_key', "%#{private_key}"]).first.website
    end
  end

  # Return the user who is in charge of the project, Client or alias
  def manager
    self.alias ? self.alias : client
  end
end
