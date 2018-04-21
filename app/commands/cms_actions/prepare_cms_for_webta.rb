module CmsActions
  class PrepareCmsForWebta
    def call(cms_request:)
      ActiveRecord::Base.transaction do
        project = CreateProject.new.call(cms_request: cms_request)
        CreateInitialRevision.new.call(cms_request: cms_request, project: project)
        ReleaseToTranslator.new.call(cms_request: cms_request)
      end
    end
  end
end
