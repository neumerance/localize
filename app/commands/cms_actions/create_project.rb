module CmsActions
  class CreateProject
    def call(cms_request:)
      name = "#{cms_request.title}-#{cms_request.id}"
      private_key = Time.now.to_i
      kind = 0

      project = Project.new(
        name: name, kind: kind,
        source: nil,
        creation_time: Time.now,
        private_key: private_key
      )

      user = cms_request.website.client

      if user.alias?
        project.client = user.master_account
        project.alias = user
      else
        project.client = user
        project.alias = nil
      end

      project.save!
      project
    end
  end
end
