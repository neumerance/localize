module Queries
  module CmsRequests
    module List
      module Statuses
        OPEN = 'open'.freeze
        REVIEWS = 'reviews'.freeze
        WAITING = 'waiting_for_review'.freeze
        COMPLETED = 'completed'.freeze
        REVIEW_COMPLETED = 'review_completed'.freeze
        TRANSLATED = 'translated'.freeze

        def self.released_to_translator?(status)
          status == Statuses::OPEN
        end

        def self.request_translated?(status)
          [TRANSLATED, REVIEWS, WAITING].include?(status)
        end

        def self.request_status(status)
          return CMS_REQUEST_RELEASED_TO_TRANSLATORS if released_to_translator?(status)
          return CMS_REQUEST_TRANSLATED if request_translated?(status)
          CMS_REQUEST_DONE
        end
      end
    end
  end
end
