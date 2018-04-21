module Queries
  module CmsRequests
    module List
      class Waiting < Base
        def all
          base_scope.
            joins(revision: { revision_languages: :managed_work }).
            joins(revision: :chats).
            where('chats.translator_id' => translator_id).
            where('managed_works.translator_id is null OR managed_works.translator_id != ?', translator_id)
        end
      end
    end
  end
end
