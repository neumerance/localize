module Queries
  module CmsRequests
    module List
      class Opened < Base
        def all
          base_scope.
            joins(revision: { chats: :bids }).
            where('bids.won = ? AND chats.translator_id = ?', true, translator_id)
        end
      end
    end
  end
end
