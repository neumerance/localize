module FactoryGirl
  module Strategy
    class Find
      def association(runner)
        runner.run
      end

      def result(evaluation)
        build_class(evaluation).where(get_overrides(evaluation)).first
      end

      private

      def build_class(evaluation)
        evaluation.instance_variable_get(:@attribute_assigner).instance_variable_get(:@build_class)
      end

      def get_overrides(evaluation = nil)
        return @overrides unless @overrides.nil?
        evaluation.instance_variable_get(:@attribute_assigner).instance_variable_get(:@evaluator).instance_variable_get(:@overrides).clone
      end
    end

    class FindOrCreate
      def initialize
        @strategy = FactoryGirl.strategy_by_name(:find).new
      end

      delegate :association, to: :@strategy

      def result(evaluation)
        found_object = @strategy.result(evaluation)

        if found_object.nil?
          @strategy = FactoryGirl.strategy_by_name(:create).new
          @strategy.result(evaluation)
        else
          found_object
        end
      end
    end
  end

  register_strategy(:find, Strategy::Find)
  register_strategy(:find_or_create, Strategy::FindOrCreate)
end

@open_jobs = 11
@translated_jobs = 6
@completed_jobs = 21
@no_xliff_jobs = 2
@translator = FactoryGirl.find_or_create(:beta_translator, email: 'beta@icanlocalize.conm')

@cms_requests = FactoryGirl.create_list(:cms_request, @open_jobs, :with_dependencies)
@cms_requests_no_xliff = FactoryGirl.create_list(:cms_request, @no_xliff_jobs, :with_dependencies)
@cms_requests_translated = FactoryGirl.create_list(:cms_request_translated, @translated_jobs, :with_dependencies)
@cms_requests_done = FactoryGirl.create_list(:cms_request_done, @completed_jobs, :with_dependencies)
@cms_requests.each do |cms|
  cms.revision.chats.each { |chat| chat.update_attribute(:translator, @translator) }
  cms.cms_target_language.update_attribute(:translator, @translator)
  FactoryGirl.create(:xliff, cms_request: cms, uploaded_data: TempContent.new("#{Rails.root}/spec/fixtures/files/xliffs/3.xliff"))
end
@cms_requests_no_xliff.each do |cms|
  cms.revision.chats.each { |chat| chat.update_attribute(:translator, @translator) }
  cms.cms_target_language.update_attribute(:translator, @translator)
end
@cms_requests_translated.each do |cms|
  cms.revision.chats.each { |chat| chat.update_attribute(:translator, @translator) }
  cms.cms_target_language.update_attribute(:translator, @translator)
  cms.revision.all_bids.where(won: true).first.update_attributes(status: BID_DECLARED_DONE)
  FactoryGirl.create(:xliff, cms_request: cms, uploaded_data: TempContent.new("#{Rails.root}/spec/fixtures/files/xliffs/3.xliff"))
end
@cms_requests_done.each do |cms|
  cms.revision.chats.each { |chat| chat.update_attribute(:translator, @translator) }
  cms.cms_target_language.update_attribute(:translator, @translator)
  cms.revision.all_bids.where(won: true).first.update_attributes(status: BID_COMPLETED)
  FactoryGirl.create(:xliff, cms_request: cms, uploaded_data: TempContent.new("#{Rails.root}/spec/fixtures/files/xliffs/3.xliff"))
end

@cms_request = FactoryGirl.create(:cms_request, :with_dependencies)
@cms_request.revision.chats.each { |chat| chat.update_attribute(:translator, @translator) }
@cms_request.cms_target_language.update_attribute(:translator, @translator)
FactoryGirl.create(:xliff, cms_request: @cms_request, uploaded_data: TempContent.new("#{Rails.root}/spec/fixtures/files/xliffs/3.xliff"))
