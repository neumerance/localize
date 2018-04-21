module Queries
  module CmsRequests
    module List
      class Completed < Base
        def all
          scope = base_scope.
                  joins(revision: { revision_languages: :managed_work }).
                  joins(revision: { chats: :bids }).
                  where('(bids.won = ? AND chats.translator_id = ?)', true, translator_id)
          latest_page_records(scope.to_a)
        end
      end
    end
  end
end
