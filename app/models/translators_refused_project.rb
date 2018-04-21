class TranslatorsRefusedProject < ApplicationRecord

  belongs_to :owner, polymorphic: true
  belongs_to :translator

  class << self
    def refuse_project(project, translator, project_type, remarks)
      create(translator: translator, owner: project, remarks: remarks, project_type: project_type)
    end
  end

end
