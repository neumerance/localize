module Queries
  module CmsRequests
    module List
      class Factory
        QUERIES = {
          Statuses::OPEN => Opened,
          Statuses::REVIEWS => UnderReview,
          Statuses::WAITING => Waiting,
          Statuses::COMPLETED => Completed,
          Statuses::REVIEW_COMPLETED => ReviewCompleted
        }.freeze

        def self.query_for(translator_id, status, job_id)
          klass = QUERIES[status] || Empty
          klass.new(translator_id, status, job_id)
        end
      end
    end
  end
end
