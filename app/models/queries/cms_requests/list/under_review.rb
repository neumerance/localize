module Queries
  module CmsRequests
    module List
      class UnderReview < Base
        def all
          base_scope.
            joins(revision: { revision_languages: :managed_work }).
            where('managed_works.translator_id = ?', translator_id)
        end
      end
    end
  end
end
