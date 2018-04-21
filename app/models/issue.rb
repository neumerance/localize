class Issue < ApplicationRecord
  belongs_to :initiator, class_name: 'User', foreign_key: :initiator_id
  belongs_to :target, class_name: 'User', foreign_key: :target_id
  belongs_to :owner, polymorphic: true
  has_many :messages, as: :owner, dependent: :destroy

  has_many :users, -> { distinct }, through: :messages, source: :user

  attr_reader :message
  attr_writer :message

  validates_presence_of :initiator_id, :target_id, :kind, :status, :owner_id, :owner_type, :title
  validate :kind_and_target_selection

  KIND_TEXT = { ISSUE_UNCLEAR_ORIGINAL => N_('Original text is not clear'),
                ISSUE_TRANSLATION_SUGGESTION => N_('Suggestion for alternative translation'),
                ISSUE_INCORRECT_TRANSLATION => N_('Translation is incorrect'),
                ISSUE_GENERAL_QUESTION => N_('General question') }.freeze

  STATUS_TEXT = { ISSUE_OPEN => N_('Issue open'),
                  ISSUE_CLOSED => N_('Issue closed') }.freeze

  TARGET_TYPE = {
    'to_translator' => Translator,
    'to_client' => Client
  }.freeze

  after_update :notify_tp_issue_closed, if: :status_changed?

  before_create :encode_title_emojis

  scope :open_issues, -> { where(status: ISSUE_OPEN) }

  def encode_title_emojis
    self.title = Rumoji.encode title
  end

  def title_with_emojis
    Rumoji.decode title
  end

  def key
    Digest::MD5.hexdigest(id.to_s + 'sfl9845kj3')
  end

  def self.potential_users(resource_language, string_translation, source_user)
    client = resource_language.text_resource.client
    translator = resource_language.selected_chat ? resource_language.selected_chat.translator : nil
    reviewer = resource_language.managed_work.translator

    potential_users = {}
    if source_user == client || source_user.is_a?(Alias)
      potential_users[translator] = 'Translator' if translator
      potential_users[reviewer] = 'Reviewer' if reviewer
    elsif reviewer && (source_user == reviewer)
      potential_users[translator] = 'Translator' if translator && (string_translation.last_editor == translator)
      potential_users[client] = 'Client'
    elsif translator && (source_user == translator)
      potential_users[reviewer] = 'Reviewer' if reviewer
      potential_users[client] = 'Client'
    end
    potential_users
  end

  def self.create_by_api(json)
    begin
      cms_request_id = json['data']['relationships']['cms_request']['data']['id']
      accesskey = json['data']['attributes']['accesskey']
      cms_request = CmsRequest.find_by_id(cms_request_id)
      return ApiError.new(404, "CmsRequest with ID: #{cms_request_id} was not found", 'NOT FOUND').json_error unless cms_request

      website_id = json['data']['relationships']['website']['data']['id'].to_i
      return ApiError.new(400, "CmsRequest with id: #{cms_request_id} does not belong to Website with id: #{website_id}", 'DATA MISSMATCH').json_error unless website_id == cms_request.website_id

      return ApiError.new(403, "Authentication using accesskey '#{accesskey}' failed for CmsRequest with ID: #{cms_request_id}", 'FORBIDDEN').json_error unless cms_request.website.accesskey == accesskey

      message_body = json['data']['attributes']['message_body']
      return ApiError.new(400, 'Message body is required, but it was empty', 'INVALID DATA').json_error if message_body.empty?

      issue = self.new
      issue.owner = cms_request
      issue.initiator = cms_request.website.client
      issue.target = cms_request.cms_target_language.translator
      issue.kind = ISSUE_INCORRECT_TRANSLATION
      issue.status = ISSUE_OPEN
      issue.tp_callback_url = json['data']['attributes']['callback_url']
      issue.title = json['data']['attributes']['subject']
      issue.message = message_body
      issue.save!

      message = Message.new(body: issue.message, chgtime: Time.now)
      message.user = issue.initiator
      message.owner = issue
      message.save!

      issue.target.create_reminder(EVENT_NEW_ISSUE_MESSAGE, issue)
      if issue.target.can_receive_emails?
        ReminderMailer.new_issue(issue.target, issue, message).deliver_now
      end
    rescue => e
      return ApiError.new(400, e.message, 'UNEXPECTED ERROR').json_error
    end
    issue.to_json
  end

  def self.get_by_api(id)
    issue = self.find_by_id(id)
    return ApiError.new(404, "Issue with ID: #{id} was not found", 'NOT FOUND').error unless issue
    issue.to_json
  rescue => e
    return ApiError.new(400, e.message, 'UNEXPECTED ERROR').error
  end

  def self.find_by_mrk(params)
    mrk_data = params['xliff_trans_unit_mrk']['data']
    xliff_trans_unit_mrk = XliffTransUnitMrk.find_by_id(mrk_data['id'])
    return ApiError.new(404, "XliffTransUnitMrk with id: #{mrk_data['id']} not found", 'NOT FOUND').error unless xliff_trans_unit_mrk
    if mrk_data['mrk_type'].present? && mrk_data['mrk_type'].to_i == XliffTransUnitMrk::MRK_TYPES[:source]
      xliff_trans_unit_mrk = xliff_trans_unit_mrk.source_mrk
      return ApiError.new(404, "Source XliffTransUnitMrk with id: #{mrk_data['id']} not found", 'NOT FOUND').error unless xliff_trans_unit_mrk
    end
    mrk_issues = Issue.where(owner: xliff_trans_unit_mrk)
    target_type = TARGET_TYPE[params[:target]]
    target_type ? mrk_issues.select { |x| x.target.is_a? target_type }.map(&:to_json) : mrk_issues.map(&:to_json)
  rescue => e
    return ApiError.new(400, e.message, 'UNEXPECTED ERROR').error
  end

  def to_json(short_version = false)
    msg_body = self.messages.first.body
    json = {
      data: {
        id: self.id,
        attributes: {
          status: STATUS_TEXT[self.status],
          message: short_version && msg_body ? msg_body.truncate(48) : msg_body
        },
        links: {
          'self': Rails.application.routes.url_helpers.issue_url(self)
        },
        messages: self.json_messages_with_user
      }
    }
    return json if short_version
    json[:data][:type] = 'support_ticket'
    json[:data][:attributes][:subject] = self.title
    json
  end

  def project
    if owner.is_a? StringTranslation
      owner.text_resource
    elsif owner.is_a? RevisionLanguage
      owner.revision
    else
      owner
    end
  end

  def json_messages_with_user
    self.messages.map do |message|
      json = message.as_json
      user = message.user
      unless user.nil?
        json['user'] = {
          name: "#{user.try(:fname)} #{user.try(:lname)}",
          nickname: user.try(:nickname),
          model: user.class.name
        }
      end
      json
    end
  end

  private

  def kind_and_target_selection
    errors.add(:kind, 'not selected') if kind == 0
    errors.add(:target_id, 'not selected') if target_id == 0
  end

  def notify_tp_issue_closed
    return true if self.tp_callback_url.nil? || self.status == ISSUE_OPEN || Rails.env.test?
    ApiResponder.notify_tp_issue_closed(self)
  rescue => e
    Rails.logger.error("Failed to notify TP about ticket closed with error: #{e.inspect}")
  end

end
