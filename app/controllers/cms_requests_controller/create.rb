class CmsRequestsController
  class Create
    attr_reader :controller, :website

    def initialize(controller, website)
      @controller = controller
      @website = website
    end

    def call
      Logging.log(self, :call)
      job_required_attrs = [:id, :file, :source_language, :target_language, :cms_id, :url, :title, :word_count]
      AuthenticateProject.enforce_hash_with_params('job', params[:job], job_required_attrs)

      @cms_request = website.cms_requests.where(tp_id: params[:job][:id], cms_id: params[:job][:cms_id]).first
      if @cms_request
        Logging.log(self, reused_existing_cms: @cms_request.id)
        return @cms_request
      end

      duplicated_page_records = CmsRequest.where(cms_id: params[:job][:cms_id], website_id: website.id).
                                where.not(status: [CMS_REQUEST_DONE, CMS_REQUEST_TRANSLATED]).to_a
      Logging.log(self, duplicated_page_records: duplicated_page_records.map(&:id))

      cancelable_cms_records = duplicated_page_records.select(&:can_cancel?)
      Logging.log(self, cancelable_cms_records: cancelable_cms_records.map(&:id))

      @non_cancelable_cms_records = duplicated_page_records.select(&:in_progress?).reject(&:can_cancel?)
      Logging.log(self, non_cancelable_cms_records: @non_cancelable_cms_records&.map(&:id))

      cms_request_data = data_for_cms_request_creation

      ActiveRecord::Base.transaction do
        @cms_request = create_cms_request!(cms_request_data)
        Logging.log(self, created_cms: @cms_request.id)

        cancelable_cms_records.each do |c|
          begin
            Logging.log(self, cancel_translation: c.id)
            cancel_result = c.cancel_translation
            Logging.log(self, cancellation_failed: c.id, error: cancel_result[:error]) unless cancel_result[:success]
          rescue StandardError => err
            Logging.log(self, class: err.class, message: err.message)
          end
        end
      end

      Logging.log(self, set_flag: @cms_request.id)
      set_parent_flags!(@cms_request)

      Logging.log(self, :create_xliff)

      if @non_cancelable_cms_records.any?
        Logging.log(self, :block_processing)

        create_xliff!(@cms_request, true)
        block_processing!(@cms_request, @non_cancelable_cms_records)
      else
        Logging.log(self, :process)

        create_xliff!(@cms_request, false)
        CmsActions::Process.new(@cms_request.id).call
      end

      CmsActions::Notifications::AlertSupportersAboutBase64.new.call(@cms_request)

      @cms_request
    end

    private

    def set_parent_flags!(cms)
      ta_records = Queries::CmsRequests::TaTool::ParentRequests.new.call(cms: cms)
      Logging.log(self, ta_tool_parent_requests: ta_records.map(&:id))

      webta_records = Queries::CmsRequests::WebtaTool::ParentRequests.new.call(cms: cms)
      Logging.log(self, webta_parent_requests: webta_records.map(&:id))

      cms.update_attributes!(
        ta_tool_parent_completed: ta_records.any?,
        webta_parent_completed: webta_records.any?
      )
    end

    def data_for_cms_request_creation
      # Make sure the source and target languages exist
      source_language = Language.find_by(name: params[:job][:source_language])
      raise Language::NotFound, params[:job][:source_language] unless source_language
      target_language = Language.find_by(name: params[:job][:target_language])
      raise Language::NotFound, params[:job][:target_language] unless target_language

      # Make sure the translator is correct, if selected
      if params[:job][:translator_id].present? && (params[:job][:translator_id].to_i != 0)
        translator = Translator.find(params[:job][:translator_id])
        raise Translator::NotFound, "Non existent translator with ID #{params[:job][:translator_id]}" unless translator
        contract = website.find_contract_for_translator(translator, source_language, target_language)
        raise Translator::NotFound, "Translator #{translator.nickname} does not have a contract for this work" unless contract
      else
        translator = nil
      end

      job_create_attrs = [:title, :cms_id, :note, :word_count, :deadline, :batch_id, :batch_count]
      default_create_attrs = {
        status: CMS_REQUEST_WAITING_FOR_PROJECT_CREATION,
        notified: 0
      }

      attrs = params[:job].slice(*job_create_attrs).merge(default_create_attrs)
      attrs[:deadline] = Time.at(attrs[:deadline].to_i).to_datetime if attrs[:deadline]

      { attrs: attrs,
        source_language: source_language,
        target_language: target_language,
        translator: translator }
    end

    def create_cms_request!(cms_request_data)
      # Create the CmsRequest. Developers may search for CmsRequest.create or
      # CmsRequest.new in order to discover where CmsRequests are created.
      # This comment allows them to find it.
      @cms_request = website.cms_requests.build(cms_request_data[:attrs])
      @cms_request.language = cms_request_data[:source_language]
      @cms_request.permlink = params[:job][:url]
      @cms_request.tp_id = params[:job][:id]
      @cms_request.pending_tas = true
      @cms_request.save!
      # Set the default review enabled/disabled state for the CmsRequest
      @cms_request.set_default_review_status(cms_request_data[:target_language])

      cms_target_language = @cms_request.cms_target_languages.build(status: CMS_TARGET_LANGUAGE_CREATED)
      cms_target_language.language = cms_request_data[:target_language]
      cms_target_language.translator = cms_request_data[:translator]
      cms_target_language.save!

      @cms_request
    end

    def create_xliff!(cms_request, skip_parsing)
      # This has to be done after cms_request is saved, so it can be parsed for webTA format
      xliff = Xliff.new
      xliff.cms_request = cms_request
      xliff.uploaded_data = params[:job][:file]
      xliff.skip_parsing = skip_parsing
      xliff.save!
    end

    def block_processing!(cms_request, non_cancelable_cms_records)
      non_cancelable_cms_records.each do |cms|
        cms.block_cms!(cms_request.id)
      end
    end

    def params
      controller.params
    end
  end
end
