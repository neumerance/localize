module Queries
  module CmsRequests
    module List
      class ReviewCompleted < Base
        def all
          scope = base_scope.
                  joins(revision: { revision_languages: :managed_work }).
                  joins(revision: { chats: :bids }).
                  where('managed_works.translator_id = ?', translator_id)
          latest_page_records(scope.to_a)
        end
      end
    end
  end
end
