module Queries
  module CmsRequests
    module List
      class Base
        attr_reader :translator_id, :status, :job_id

        def initialize(translator_id, status, job_id)
          @translator_id = translator_id
          @status = status
          @job_id = job_id
        end

        def all
          raise NotImplementedError
        end

        def all_for_webta
          as_webta_attributes(all)
        end

        def as_webta_attributes(records)
          records.map { |record| safe_webta_attrs(record) }.compact
        end

        private

        def safe_webta_attrs(record)
          record.webta_attributes(true)
        rescue StandardError => e
          Logging.error(e, class: self.class, record_id: record.try(:id))
          nil
        end

        def base_scope
          cms_requests = CmsRequest.includes(:xliff_trans_unit_mrks).
                         includes({ revision: :project }, :language, :website).
                         includes(xliffs: :xliff_trans_unit_mrks).
                         where('cms_requests.status' => Statuses.request_status(status)).
                         where(xliff_processed: true)
          cms_requests = cms_requests.where('cms_requests.id LIKE ?', "%#{job_id}%") if job_id.present?
          cms_requests
        end

        def latest_page_records(all_records)
          grouped_records = all_records.group_by { |x| [x.website_id, x.cms_id] }
          grouped_records.values.map { |x| x.max_by(&:id) }
        end
      end
    end
  end
end
