class WebSupport < ApplicationRecord
  belongs_to :client

  has_many :client_departments, dependent: :destroy
  has_many :web_dialogs, through: :client_departments
  has_many :pending_web_dialogs,
           -> { where('web_dialogs.status IN (?)', [SUPPORT_TICKET_CREATED, SUPPORT_TICKET_WAITING_REPLY]) },
           through: :client_departments,
           source: :web_dialogs,
           class_name: 'WebDialog'

  has_many :brandings, as: :owner, dependent: :destroy

  has_one :text_resource, as: :owner

  validates_presence_of :name, :client_id
end
