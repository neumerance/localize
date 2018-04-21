require 'rails_helper'

describe PeriodicChecker do
  include ActionDispatch::TestProcess

  describe 'clean user token' do
    let!(:recent_user_token) { FactoryGirl.create(:user_token) }
    let!(:old_user_token) { FactoryGirl.create(:user_token, created_at: Time.now - UserToken::CLEAN_AFTER - 1.minute) }

    it 'should clean old token' do
      expect(UserToken.count).to eq(2)
      checker = PeriodicChecker.new(Time.now)
      cleaned = checker.clean_user_tokens
      expect(cleaned).to eq(1)
      expect(UserToken.find_by_id(recent_user_token.id)).to eq(recent_user_token)
      expect(UserToken.find_by_id(old_user_token.id)).to be_nil
    end
  end

  describe '#add_notification_to_translator' do
    # Setup test data
    # Create a Software Project with one target language, an associated
    # translator and an associated review job. Also create a second
    # translator that is not associated with that project.
    let!(:client) { FactoryGirl.create(:client) }

    let!(:translator_language_from) do
      FactoryGirl.create(
        :translate_from_english,
        status: TRANSLATOR_LANGUAGE_APPROVED
      )
    end

    let!(:translator_language_to) do
      FactoryGirl.create(
        :translate_to_french,
        status: TRANSLATOR_LANGUAGE_APPROVED
      )
    end

    let!(:project) do
      FactoryGirl.create(
        :text_resource,
        language: translator_language_from.language
      )
    end

    let!(:resource_language) do
      FactoryGirl.create(
        :resource_language,
        language: translator_language_to.language,
        text_resource: project
      )
    end

    let!(:selected_chat) do
      FactoryGirl.create(
        :resource_chat,
        resource_language: resource_language
      )
    end

    let!(:unexpected_translator) do
      FactoryGirl.create(
        :translator,
        userstatus: USER_STATUS_QUALIFIED,
        # This is a bitmask used to store multiple configurations in a single
        # integer column. 3 is equivalent to binary "11", which means two
        # boolean "true".
        notifications: 3,
        level: EXPERT_TRANSLATOR,
        resource_chats: [selected_chat],
        translator_language_froms: [translator_language_from],
        translator_language_tos: [translator_language_to]
      )
    end

    let!(:expected_translator) do
      FactoryGirl.create(
        :translator,
        userstatus: USER_STATUS_QUALIFIED,
        notifications: 3,
        level: EXPERT_TRANSLATOR,
        translator_language_froms: [translator_language_from],
        translator_language_tos: [translator_language_to]
      )
    end

    # Create a review for the above Software Project
    let!(:managed_work) do
      FactoryGirl.create(
        :managed_work,
        owner: project,
        active: MANAGED_WORK_ACTIVE,
        notified: 0,
        client: client,
        to_language: translator_language_to.language
      )
    end

    before(:each) do
      # Generate and "send" e-mail with new project suggestions for translators
      checker = PeriodicChecker.new(Time.now)
      _, @translator_notifications = checker.per_profile_mailer(nil, false, true)
    end

    it 'notifies qualified translators about new review jobs' do
      managed_works_for_expected_translator =
        @translator_notifications.dig(expected_translator, 'managed_works')
      expect(managed_works_for_expected_translator).to include(managed_work)
    end

    # The same person cannot be both the translator and the reviewer of the
    # same target language in a project, or else he would be reviewing his
    # own work.
    it 'review job suggestions sent by e-mail to translators do NOT include projects translated by the recipient' do
      managed_works_for_unexpected_translator =
        @translator_notifications.dig(unexpected_translator, 'managed_works')
      RSpec::Matchers.define_negated_matcher :not_include, :include
      expect(managed_works_for_unexpected_translator).to \
        be_nil.or not_include(managed_work)
    end
  end
end
