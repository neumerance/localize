module CmsActions
  class CreateInitialRevision
    def call(cms_request:, project:)
      revision = Revision.new(
        name: 'Initial',
        creation_time: Time.now,
        released: 0,
        max_bid_currency: 1,
        language_id: cms_request.language_id,
        private_key: project.private_key,
        kind: project.kind,
        project_completion_duration: 4,
        project_id: project.id,
        cms_request_id: cms_request.id
      )

      revision.base_copy(project.revisions.last) if project.revisions.any?

      project.revisions << revision

      project.save
      revision.save

      revision
    end
  end
end
