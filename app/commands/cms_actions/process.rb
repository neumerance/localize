module CmsActions
  class Process
    attr_reader :cms_request

    def initialize(cms_request_id)
      @cms_request_id = cms_request_id
    end

    def call
      cms_request = CmsRequest.find(@cms_request_id)
      run_tas_on_cms_request!(cms_request)

      # Create WebsiteTranslationOffer if it does not yet exist.
      # If its the first time a client sends contents for a given target
      # language, then a WTO is created. If it's not the first time, it will
      # already exist.
      # The default translator assignment mode is set by a callback at the model.
      wto = WebsiteTranslationOffer.find_or_create_by!(
        from_language: cms_request.language,
        to_language: cms_request.cms_target_language.language,
        website: cms_request.website
      )

      # Create a ManagedWork (review) for the above WebsiteTranslationOffer if
      # it doesn't already have one.
      # We have ManagedWork objects associated with WebsiteTranslationOffers
      # (one per language pair) and associated with RevisionLanguage (one per
      # CmsRequest). The ManagedWork we're creating here is only used to
      # determine that review should be enabled by default for all CmsRequests
      # of this language pair.
      existing_review = ManagedWork.where(owner: wto).take
      if existing_review.nil?
        ManagedWork.create(
          owner: wto,
          active: MANAGED_WORK_ACTIVE,
          translation_status: MANAGED_WORK_CREATED,
          from_language: wto.from_language,
          to_language: wto.to_language,
          client: wto.website.client
        )
      end
    end

    private

    # Method called from create, when comes from TP
    def run_tas_on_cms_request!(cms_request)
      unless Rails.env.test?
        begin
          tas_comm = TasComm.new
          tas_comm.create_project(cms_request, Rails.logger)
        rescue
          cms_request.tas_failed = true
          cms_request.save!
          raise 'Not able to deliver this CmsRequest to TAS'
        end
      end
    end
  end
end
