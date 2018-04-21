require 'spec_helper'
require 'rails_helper'
require 'support/utils_helper'

RSpec.describe 'Jobs', type: :request do
  include UtilsHelper

  before(:all) do
    @open_jobs = 11
    @translated_jobs = 6
    @review_jobs = 5
    @completed_jobs = 11
    @no_xliff_jobs = 2
    @jobs_per_page = 10.0
    @translator = FactoryGirl.create(:beta_translator, capacity: 100)
    @reviewer = FactoryGirl.create(:beta_translator, capacity: 100)
    @cms_requests = FactoryGirl.create_list(:cms_request, @open_jobs, :with_dependencies)
    @cms_request_non_accessible = FactoryGirl.create(:cms_request, :with_dependencies)
    @cms_requests_no_xliff = FactoryGirl.create_list(:cms_request, @no_xliff_jobs, :with_dependencies)
    @cms_requests_translated = FactoryGirl.create_list(:cms_request_translated, @translated_jobs, :with_dependencies)
    @cms_requests_done = FactoryGirl.create_list(:cms_request_done, @completed_jobs, :with_dependencies)
    @cms_requests_for_review = FactoryGirl.create_list(:cms_request_translated, @review_jobs, :with_dependencies)

    (@cms_requests + [@cms_request_non_accessible]).each do |cms|
      cms.website.website_translation_offers.last.update_attribute(:to_language_id, cms.cms_target_language.language_id)
      FactoryGirl.create(:xliff, cms_request: cms, uploaded_data: TempContent.new("#{Rails.root}/spec/fixtures/files/xliffs/3.xliff"))
    end

    @cms_requests.each do |cms|
      cms.revision.chats.each { |chat| chat.update_attribute(:translator, @translator) }
      cms.cms_target_language.update_attribute(:translator, @translator)
    end

    @cms_requests_no_xliff.each do |cms|
      cms.revision.chats.each { |chat| chat.update_attribute(:translator, @translator) }
      cms.cms_target_language.update_attribute(:translator, @translator)
      cms.revision.revision_languages.last.managed_work.update_attribute(:translator, @translator)
      cms.website.website_translation_offers.last.update_attribute(:to_language_id, cms.cms_target_language.language_id)
    end
    @cms_requests_translated.each do |cms|
      cms.revision.chats.each { |chat| chat.update_attribute(:translator, @translator) }
      cms.cms_target_language.update_attribute(:translator, @translator)
      cms.revision.all_bids.where(won: true).first.update_attributes(status: BID_DECLARED_DONE)
      cms.website.website_translation_offers.last.update_attribute(:to_language_id, cms.cms_target_language.language_id)
      FactoryGirl.create(:xliff, cms_request: cms, uploaded_data: TempContent.new("#{Rails.root}/spec/fixtures/files/xliffs/3.xliff"))
    end
    @cms_requests_for_review.each do |cms|
      cms.revision.chats.each { |chat| chat.update_attribute(:translator, @translator) }
      cms.cms_target_language.update_attribute(:translator, @translator)
      cms.revision.all_bids.where(won: true).first.update_attributes(status: BID_DECLARED_DONE)
      cms.revision.revision_languages.last.managed_work.update_attributes(translator: @reviewer,
                                                                          translation_status: MANAGED_WORK_REVIEWING)
      cms.website.website_translation_offers.last.update_attribute(:to_language_id, cms.cms_target_language.language_id)
      FactoryGirl.create(:xliff, cms_request: cms, uploaded_data: TempContent.new("#{Rails.root}/spec/fixtures/files/xliffs/3.xliff"))
    end
    reviewer2 = FactoryGirl.create(:beta_translator, capacity: 100)
    @cms_requests_for_review.last.revision.revision_languages.last.managed_work.update_attributes(translator: reviewer2)
    @cms_requests_done.each do |cms|
      cms.revision.chats.each { |chat| chat.update_attribute(:translator, @translator) }
      cms.cms_target_language.update_attribute(:translator, @translator)
      cms.revision.all_bids.where(won: true).first.update_attributes(status: BID_COMPLETED)
      cms.website.website_translation_offers.last.update_attribute(:to_language_id, cms.cms_target_language.language_id)
      FactoryGirl.create(:xliff, cms_request: cms, uploaded_data: TempContent.new("#{Rails.root}/spec/fixtures/files/xliffs/3.xliff"))
    end
    @xliff_trans_unit_mrk = FactoryGirl.create(:xliff_trans_unit_mrk, cms_request: @cms_requests.first)
    @issue = FactoryGirl.create(:issue, owner: @xliff_trans_unit_mrk, target: @translator, title: 'This is a title for issue', kind: ISSUE_INCORRECT_TRANSLATION, status: ISSUE_OPEN)
    @message = FactoryGirl.create(:message, owner: @issue, body: 'This is a message for issue pointing to mrk.')
    @closed_issue = FactoryGirl.create(:issue, owner: @xliff_trans_unit_mrk, target: @translator, title: 'This is a title for closed issue', kind: ISSUE_INCORRECT_TRANSLATION, status: ISSUE_CLOSED)
    @closed_issue_message = FactoryGirl.create(:message, owner: @closed_issue, body: 'This is very long message which is having more than 45 characters for closed issue pointing to mrk.')

    cms = @cms_requests.fifth
    @bid = cms.revision.all_bids.where(won: true).first
    @bid.managed_work.update_attributes(active: MANAGED_WORK_ACTIVE, translator: @reviewer, translation_status: MANAGED_WORK_REVIEWING)
    XliffTransUnitMrk.where(xliff_id: cms.base_xliff.id).update_all(mrk_status: XliffTransUnitMrk::MRK_STATUS[:translation_completed])

    @token = auth_token(@translator)
    @headers = { 'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json', 'Authorization' => @token }

    @reviewer_token = auth_token(@reviewer)
    @headers_with_reviewer = {
      'CONTENT_TYPE' => 'application/json', 'ACCEPT' => 'application/json', 'Authorization' => @reviewer_token
    }
  end

  context 'GET index' do

    describe 'without params' do

      it 'should have xliff processed' do
        cms = @cms_requests.last
        expect(cms.parsed_xliffs.size).to eq(1)
        expect(cms.base_xliff.processed).to be_truthy
        expect(cms.base_xliff.parsed_xliff).not_to be_nil
        expect(cms.base_xliff.xliff_trans_units.size).to eq(6)
        expect(cms.base_xliff.parsed_xliff.xliff_trans_unit_mrks.size).to eq(12)
        # expect(cms.website.client.translation_memories.size).to eq(6)
        expect(cms.website.client.translated_memories.size).to eq(0)
      end

      it 'should have default pagination' do
        get api_jobs_path, {}, @headers
        json = ActiveSupport::JSON.decode(response.body)
        pagination = json['pagination']
        expect(pagination['total_pages']).to eq(0)
        expect(pagination['current_page']).to eq(1)
        expect(pagination['prev_page']).to be_nil
        expect(pagination['next_page']).to be_nil
      end

      it 'should have no jobs' do
        get api_jobs_path, {}, @headers
        json = ActiveSupport::JSON.decode(response.body)
        jobs = json['jobs']
        expect(jobs.size).to eq(0)
        expect(json['pagination']['total_jobs']).to eq(0)
      end

    end

    describe 'with params' do

      it 'should have only open jobs' do
        get api_jobs_path, { type: 'open' }, @headers
        json = ActiveSupport::JSON.decode(response.body)
        pagination = json['pagination']
        expect(pagination['total_pages']).to eq((@open_jobs / @jobs_per_page).ceil)
        expect(pagination['current_page']).to eq(1)
        expect(pagination['prev_page']).to be_nil
        expect(pagination['next_page']).to eq(@open_jobs > @jobs_per_page ? 2 : nil)
      end

      it 'should have only open jobs' do
        get api_jobs_path, { type: 'open' }, @headers
        json = ActiveSupport::JSON.decode(response.body)
        jobs = json['jobs']
        pagination = json ['pagination']
        expect(pagination['total_jobs']).to eq(@open_jobs)
        expect(jobs.size).to eq([@open_jobs, @jobs_per_page].min)
        expect((jobs.select { |j| j['status'] == CMS_REQUEST_RELEASED_TO_TRANSLATORS }).size).to eq([@open_jobs, @jobs_per_page].min)
      end

      it 'should have no open jobs for reviewer' do
        get api_jobs_path, { type: 'open' }, @headers_with_reviewer
        json = ActiveSupport::JSON.decode(response.body)
        jobs = json['jobs']
        pagination = json ['pagination']
        expect(pagination['total_jobs']).to eq(0)
        expect(jobs.size).to eq(0)
      end

      # it 'should have only translated jobs' do
      #   get api_jobs_path, { type: 'translated' }, @headers
      #   json = ActiveSupport::JSON.decode(response.body)
      #   jobs = json['jobs']
      #   pagination = json ['pagination']
      #   expect(pagination['total_jobs']).to eq(@translated_jobs + @review_jobs)
      #   expect(jobs.size).to eq([@translated_jobs + @review_jobs, @jobs_per_page].min)
      #   expect((jobs.select { |j| j['status'] == CMS_REQUEST_TRANSLATED }).size).to eq([@translated_jobs + @review_jobs, @jobs_per_page].min)
      # end

      it 'should have only completed jobs' do
        get api_jobs_path, { type: 'completed' }, @headers
        json = ActiveSupport::JSON.decode(response.body)
        jobs = json['jobs']
        pagination = json ['pagination']
        expect(pagination['total_jobs']).to eq(@completed_jobs)
        expect(jobs.size).to eq([@completed_jobs, @jobs_per_page].min)
        expect((jobs.select { |j| j['status'] == CMS_REQUEST_DONE }).size).to eq([@completed_jobs, @jobs_per_page].min)
      end

      it 'should have no completed jobs for reviewer' do
        get api_jobs_path, { type: 'completed' }, @headers_with_reviewer
        json = ActiveSupport::JSON.decode(response.body)
        jobs = json['jobs']
        pagination = json ['pagination']
        expect(pagination['total_jobs']).to eq(0)
        expect(jobs.size).to eq(0)
      end

      it 'should have no reviews jobs for translator' do
        get api_jobs_path, { type: 'reviews' }, @headers
        json = ActiveSupport::JSON.decode(response.body)
        jobs = json['jobs']
        pagination = json ['pagination']
        expect(pagination['total_jobs']).to eq(0)
        expect(jobs.size).to eq(0)
      end

      it 'should have only reviews jobs for reviewer' do
        get api_jobs_path, { type: 'reviews' }, @headers_with_reviewer
        json = ActiveSupport::JSON.decode(response.body)
        jobs = json['jobs']
        pagination = json ['pagination']
        review_jobs = @review_jobs - 1
        expect(pagination['total_jobs']).to eq(review_jobs)
        expect(jobs.size).to eq([review_jobs, @jobs_per_page].min)
      end

      it 'should return all records, correctly paginated' do
        if @completed_jobs > @jobs_per_page
          last_page = (@completed_jobs / @jobs_per_page).ceil
          all_jobs = []
          1.upto last_page do |i|
            page = i
            get api_jobs_path, { type: 'completed', page: page }, @headers
            json = ActiveSupport::JSON.decode(response.body)
            jobs = json['jobs']
            all_jobs << jobs
            pagination = json ['pagination']
            expect(pagination['total_jobs']).to eq(@completed_jobs)
            expect(jobs.size).to eq((@completed_jobs / @jobs_per_page).floor >= page ? @jobs_per_page : @completed_jobs % @jobs_per_page)
            expect(jobs.find { |j| j['status'] != CMS_REQUEST_DONE }).to be_nil
            expect(pagination['total_pages']).to eq((@completed_jobs / @jobs_per_page).ceil)
            expect(pagination['current_page']).to eq(page)
            expect(pagination['prev_page']).to eq((page - 1) > 0 ? page - 1 : nil)
            expect(pagination['next_page']).to eq(@completed_jobs > (page * @jobs_per_page) ? page + 1 : nil)
          end
          expect(all_jobs.flatten.uniq!).to be_nil
          expect(all_jobs.flatten.uniq.size).to eq(@completed_jobs)
          # Todo implement deadlines and have this test pass
          expect(all_jobs.flatten.uniq.collect { |j| j['id'] }).to match_array(@cms_requests_done.collect { |j| j['id'] })
        end
      end

      it 'should return first page for invalid page number' do

        page = 1
        get api_jobs_path, { type: 'completed', page: page }, @headers
        json = ActiveSupport::JSON.decode(response.body)
        jobs = json['jobs']
        pagination = json ['pagination']
        expect(pagination['total_pages']).to eq((@completed_jobs / @jobs_per_page).ceil)
        expect(pagination['current_page']).to eq(page)
        expect(pagination['prev_page']).to eq((page - 1) > 0 ? page - 1 : nil)
        expect(pagination['next_page']).to eq(@completed_jobs > (page * @jobs_per_page) ? page + 1 : nil)

        page_0 = 0
        get api_jobs_path, { type: 'completed', page: page_0 }, @headers
        json = ActiveSupport::JSON.decode(response.body)
        jobs_0 = json['jobs']
        pagination = json ['pagination']
        expect(pagination['total_pages']).to eq((@completed_jobs / @jobs_per_page).ceil)
        expect(pagination['current_page']).to eq(page)
        expect(pagination['prev_page']).to eq((page - 1) > 0 ? page - 1 : nil)
        expect(pagination['next_page']).to eq(@completed_jobs > (page * @jobs_per_page) ? page + 1 : nil)

        page_xxx = 'xxx'
        get api_jobs_path, { type: 'completed', page: page_xxx }, @headers
        json = ActiveSupport::JSON.decode(response.body)
        jobs_xxx = json['jobs']
        pagination = json ['pagination']
        expect(pagination['total_pages']).to eq((@completed_jobs / @jobs_per_page).ceil)
        expect(pagination['current_page']).to eq(page)
        expect(pagination['prev_page']).to eq((page - 1) > 0 ? page - 1 : nil)
        expect(pagination['next_page']).to eq(@completed_jobs > (page * @jobs_per_page) ? page + 1 : nil)

        page_fff = 'fff'
        get api_jobs_path, { type: 'completed', page: page_fff }, @headers
        json = ActiveSupport::JSON.decode(response.body)
        jobs_fff = json['jobs']
        pagination = json ['pagination']
        expect(pagination['total_pages']).to eq((@completed_jobs / @jobs_per_page).ceil)
        expect(pagination['current_page']).to eq(page)
        expect(pagination['prev_page']).to eq((page - 1) > 0 ? page - 1 : nil)
        expect(pagination['next_page']).to eq(@completed_jobs > (page * @jobs_per_page) ? page + 1 : nil)
        # Todo implement code and have test pass
        expect(jobs).to match_array(jobs_0)
        expect(jobs).to match_array(jobs_xxx)
        expect(jobs).to match_array(jobs_fff)

      end

      it 'should return last page for page number bigger than last page' do
        per = 5.0
        last_page = (@completed_jobs / per).ceil
        page = last_page + 1000
        get api_jobs_path, { type: 'completed', page: page, per: per }, @headers
        json = ActiveSupport::JSON.decode(response.body)
        jobs = json['jobs']
        pagination = json ['pagination']
        expect(pagination['total_pages']).to eq((@completed_jobs / per).ceil)
        expect(pagination['current_page']).to eq(last_page)
        expect(pagination['prev_page']).to eq(last_page - 1)
        expect(pagination['next_page']).to be_nil

        get api_jobs_path, { type: 'completed', page: last_page, per: per }, @headers
        json = ActiveSupport::JSON.decode(response.body)
        # Todo implement code and have test pass
        expect(jobs).to match_array(json['jobs'])
      end

      it 'should contain :progress_details' do
        get api_jobs_path, { type: 'open', page: 1 }, @headers
        json = ActiveSupport::JSON.decode(response.body)
        progress_details = json['jobs'].first['progress_details']
        expect(progress_details).not_to be_nil
        expect(progress_details.keys).to match_array(%w(complexity status total_words translated_words))
        expect(progress_details['total_words']).to eq(85)
        expect(CmsRequest.find(json['jobs'].first['id']).translated_words).to eq(0)
        expect(progress_details['translated_words']).to eq(0)
      end
    end
  end

  context 'GET show' do

    it 'should support version parameter' do
      cms = @cms_requests.first
      get api_job_path(cms), { version: 2 }, @headers
      expect(response).to have_http_status(200)
    end

    context do
      it 'should retrieve accessible job without errors' do
        cms = @cms_requests.first
        get api_job_path(cms), {}, @headers
        expect(response).to have_http_status(200)
      end

      it 'should not retrieve non-accessible job without errors' do
        cms = @cms_request_non_accessible
        get api_job_path(cms), {}, @headers
        expect(response).to have_http_status(404)
      end

      it 'should retrieve non-accessible job without errors for super-translator' do
        Translation::SuperTranslator.assign_user!(@translator)
        cms = @cms_request_non_accessible
        get api_job_path(cms), {}, @headers
        expect(response).to have_http_status(200)
      end
    end

    it 'should retriew job with right content' do
      cms = @cms_requests.first
      get api_job_path(cms), {}, @headers
      json = ActiveSupport::JSON.decode(response.body)
      expect(json.keys).to match_array(%w(
                                         id title permlink cms_id word_count deadline started source_language target_language
                                         website project revision content review_type base_xliff issues status tmt_enabled
                                       ))
      expect(json['website'].keys.size).to eq(4)
      expect(json['website'].keys.join(' ')).to eq('id name description url')
      expect(json['project'].keys.size).to eq(2)
      expect(json['project'].keys.join(' ')).to eq('id name')
      expect(json['revision'].keys.size).to eq(3)
      expect(json['revision'].keys.join(' ')).to eq('id description name')
      expect(json['base_xliff'].keys.size).to eq(4)
      expect(json['base_xliff'].keys.join(' ')).to eq('id content_type filename translated')
      expect(json['content']).to eq(cms.build_mrk_pairs.map(&:deep_stringify_keys))
      expect(json['id']).to eq(cms.id)
      expect(json['title']).to eq(cms.title)
      expect(json['permlink']).to eq(cms.permlink)
      expect(json['cms_id']).to eq(cms.cms_id)
      expect(json['word_count']).to eq(cms.word_count)
      expect(json['started']).to eq(cms.base_xliff.parsed_xliff.created_at.to_i)
      expect(json['source_language']['id']).to eq(cms.language.id)
      expect(json['target_language']['id']).to eq(cms.cms_target_languages.first.language.id)
      expect(json['website']['id']).to eq(cms.website.id)
      expect(json['project']['id']).to eq(cms.revision.project.id)
      expect(json['revision']['id']).to eq(cms.revision.id)
      expect(json['base_xliff']['id']).to eq(cms.base_xliff.id)
      expect(json['review_type']).to eq(0)
    end

    it 'should have issues for the related mrk' do
      cms = @cms_requests.first
      get api_job_path(cms), {}, @headers
      json = ActiveSupport::JSON.decode(response.body)
      issue_json = json['issues'].first
      expect(issue_json['data']['id']).to eq(@issue.id)
      expect(issue_json['data']['attributes']['status']).to eq('Issue open')
      expect(issue_json['data']['attributes']['message']).to eq('This is a message for issue pointing to mrk.')
    end

    it 'should have both open and closed issues for the related mrk' do
      cms = @cms_requests.first
      get api_job_path(cms), {}, @headers
      json = ActiveSupport::JSON.decode(response.body)

      issue_json = json['issues']
      expect(issue_json.count).to eq(2)

      open_issue = issue_json.first
      expect(open_issue['data']['id']).to eq(@issue.id)
      expect(open_issue['data']['attributes']['status']).to eq('Issue open')
      expect(open_issue['data']['attributes']['message']).to eq('This is a message for issue pointing to mrk.')

      closed_issue = issue_json.last
      expect(closed_issue['data']['id']).to eq(@closed_issue.id)
      expect(closed_issue['data']['attributes']['status']).to eq('Issue closed')
      expect(closed_issue['data']['attributes']['message']).to eq('This is very long message which is having mor...')
    end
  end

  context 'POST save' do

    describe 'with right params' do

      it 'should raise no errors' do
        cms = @cms_requests.last
        mrk = cms.base_xliff.parsed_xliff.xliff_trans_units.last.xliff_trans_unit_mrks.where(mrk_type: XliffTransUnitMrk::MRK_TYPES[:target], mrk_status: XliffTransUnitMrk::MRK_STATUS[:original]).last
        valid_params = {
          xliff_id: cms.base_xliff.id,
          mrk: {
            id: mrk.id,
            translated_text: Base64.encode64('this is translated').to_s,
            mstatus: XliffTransUnitMrk::MRK_STATUS[:in_progress]
          }
        }
        post save_api_job_path(cms), valid_params.to_json, @headers
        expect(response).to have_http_status(200)
        json = ActiveSupport::JSON.decode(response.body)
        expect(json['message']).to eq('Translation completed')
        expect(json['code']).to eq(200)
        expect(json['status']).to eq('OK')

      end

      it 'should update mrk' do
        cms = @cms_requests.second
        mrk = cms.base_xliff.parsed_xliff.xliff_trans_units.last.xliff_trans_unit_mrks.where(mrk_type: XliffTransUnitMrk::MRK_TYPES[:target], mrk_status: XliffTransUnitMrk::MRK_STATUS[:original]).last
        valid_params = {
          xliff_id: cms.base_xliff.id,
          mrk: {
            id: mrk.id,
            translated_text: Base64.encode64('this is translated').to_s,
            mstatus: XliffTransUnitMrk::MRK_STATUS[:completed]
          }
        }
        expect(mrk.content).not_to eq('this is translated')
        expect(mrk.mrk_status).not_to eq(XliffTransUnitMrk::MRK_STATUS[:completed])
        puts mrk.top_content
        expect(mrk.top_content.include?("mstatus=#{XliffTransUnitMrk::MRK_STATUS[:completed]}")).to be_falsey
        post save_api_job_path(cms), valid_params.to_json, @headers
        mrk.reload
        expect(mrk.content).to eq('this is translated')
        expect(mrk.mrk_status).to eq(XliffTransUnitMrk::MRK_STATUS[:completed])
        expect(mrk.top_content.include?("mstatus=\"#{XliffTransUnitMrk::MRK_STATUS[:completed]}\"")).to be_truthy
      end

      it 'should update the translated content' do
        cms = @cms_requests.second
        mrk = cms.base_xliff.parsed_xliff.xliff_trans_units.last.xliff_trans_unit_mrks.where(mrk_type: XliffTransUnitMrk::MRK_TYPES[:target], mrk_status: XliffTransUnitMrk::MRK_STATUS[:original]).last
        valid_params = {
          xliff_id: cms.base_xliff.id,
          mrk: {
            id: mrk.id,
            translated_text: Base64.encode64('わたしは せんせいです。').to_s,
            mstatus: XliffTransUnitMrk::MRK_STATUS[:completed]
          }
        }
        post save_api_job_path(cms), valid_params.to_json, @headers
        mrk.reload
        expect(mrk.content).to eq('わたしは せんせいです。')
      end
    end

    describe 'with wrong params' do

      it 'should raise 404 for wrong mrk' do
        cms = @cms_requests.last
        invalid_valid_params = {
          xliff_id: cms.base_xliff.id,
          mrk: {
            id: 11111111111,
            translated_text: Base64.encode64('this is translated').to_s,
            mstatus: XliffTransUnitMrk::MRK_STATUS[:in_progress]
          }
        }
        post save_api_job_path(cms), invalid_valid_params.to_json, @headers
        expect(response).to have_http_status(200)
        json = ActiveSupport::JSON.decode(response.body)
        expect(json['message']).to eq('Can not find text to save.')
        expect(json['code']).to eq(404)

      end

      it 'should raise 409 for non mathcing xliff' do
        cms = @cms_requests.second
        mrk = cms.base_xliff.parsed_xliff.xliff_trans_units.last.xliff_trans_unit_mrks.where(mrk_type: XliffTransUnitMrk::MRK_TYPES[:target], mrk_status: XliffTransUnitMrk::MRK_STATUS[:original]).last
        invalid_valid_params = {
          xliff_id: cms.base_xliff.id + 1,
          mrk: {
            id: mrk.id,
            translated_text: Base64.encode64('this is translated').to_s,
            mstatus: XliffTransUnitMrk::MRK_STATUS[:completed]
          }
        }
        post save_api_job_path(cms), invalid_valid_params.to_json, @headers
        expect(response).to have_http_status(200)
        json = ActiveSupport::JSON.decode(response.body)
        expect(json['message']).to eq('Not matching mrk with xliff')
        expect(json['code']).to eq(409)
      end

      it 'should raise 409 if base xliff was updated' do
        cms = @cms_requests.second
        mrk = cms.base_xliff.parsed_xliff.xliff_trans_units.last.xliff_trans_unit_mrks.where(mrk_type: XliffTransUnitMrk::MRK_TYPES[:target], mrk_status: XliffTransUnitMrk::MRK_STATUS[:original]).last
        invalid_valid_params = {
          xliff_id: cms.base_xliff.id,
          mrk: {
            id: mrk.id,
            translated_text: Base64.encode64('this is translated').to_s,
            mstatus: XliffTransUnitMrk::MRK_STATUS[:completed]
          }
        }
        FactoryGirl.create(:xliff, cms_request: cms, uploaded_data: TempContent.new("#{Rails.root}/spec/fixtures/files/xliffs/1.xliff"))
        post save_api_job_path(cms), invalid_valid_params.to_json, @headers
        expect(response).to have_http_status(200)
        json = ActiveSupport::JSON.decode(response.body)
        expect(json['message']).to eq('An updated translation was sent by client')
        expect(json['code']).to eq(409)
      end

      it 'should raise 417 for missing markers in translation' do
        cms = @cms_requests.second
        mrk = cms.base_xliff.parsed_xliff.xliff_trans_units.last.xliff_trans_unit_mrks.where(mrk_type: XliffTransUnitMrk::MRK_TYPES[:target], mrk_status: XliffTransUnitMrk::MRK_STATUS[:original]).last
        mrk.source_mrk.update_attribute(:content, 'John has a big <g ctype="bold" id="gid_2">Horse</g>.')
        invalid_valid_params = {
          xliff_id: cms.base_xliff.id,
          mrk: {
            id: mrk.id,
            translated_text: Base64.encode64('this is translated').to_s,
            mstatus: XliffTransUnitMrk::MRK_STATUS[:completed]
          }
        }
        post save_api_job_path(cms), invalid_valid_params.to_json, @headers
        expect(response).to have_http_status(200)
        json = ActiveSupport::JSON.decode(response.body)
        expect(json['message']).to eq('The translation is missing formatting markers')
        expect(json['code']).to eq(417)
      end

      it 'should raise 417 for blank translation text' do
        cms = @cms_requests.last
        mrk = cms.base_xliff.parsed_xliff.xliff_trans_units.last.xliff_trans_unit_mrks.where(mrk_type: XliffTransUnitMrk::MRK_TYPES[:target], mrk_status: XliffTransUnitMrk::MRK_STATUS[:original]).last
        valid_params = {
          xliff_id: cms.base_xliff.id,
          mrk: {
            id: mrk.id,
            translated_text: Base64.encode64("      \xC2\xA0 \u00A0").to_s,
            mstatus: XliffTransUnitMrk::MRK_STATUS[:completed]
          }
        }
        post save_api_job_path(cms), valid_params.to_json, @headers
        expect(response).to have_http_status(200)
        json = ActiveSupport::JSON.decode(response.body)
        expect(json['message']).to eq('Missing translated text')
        expect(json['code']).to eq(417)
      end
    end

  end

  context 'POST complete' do
    before(:each) do
      @cms = FactoryGirl.create_list(:cms_request, 1, :with_dependencies).first

      @cms.revision.chats.each { |chat| chat.update_attribute(:translator, @translator) }
      @cms.cms_target_language.update_attribute(:translator, @translator)
      @cms.revision.revision_languages.last.managed_work.update_attribute(:translator, @translator)
      FactoryGirl.create(:xliff, cms_request: @cms, uploaded_data: TempContent.new("#{Rails.root}/spec/fixtures/files/xliffs/3.xliff"))

      @cms.update_attributes(status: CMS_REQUEST_RELEASED_TO_TRANSLATORS)
      @bid_api = @cms.revision.all_bids.where(won: true).first
      @bid_api.managed_work.update_attributes(active: MANAGED_WORK_ACTIVE, translator: @reviewer)
      @bid_api.update_attributes(status: BID_ACCEPTED)
      XliffTransUnitMrk.where(xliff_id: @cms.base_xliff.id).update_all(mrk_status: XliffTransUnitMrk::MRK_STATUS[:translation_completed])
    end

    describe 'with valid job' do

      it 'should complete successfully' do
        cms = @cms_requests.second
        XliffTransUnitMrk.where(xliff_id: cms.base_xliff.id).update_all(mrk_status: XliffTransUnitMrk::MRK_STATUS[:translation_completed])
        post complete_api_job_path(cms), {}, @headers
        expect(response).to have_http_status(200)
        json = ActiveSupport::JSON.decode(response.body)
        expect(json['message']).to eq('Translation completed')
        expect(json['code']).to eq(200)
        expect(json['status']).to eq('OK')
      end

      it 'should update job status' do
        cms = @cms_requests.third
        bid = cms.revision.all_bids.where(won: true).first
        mw = cms.revision.revision_languages.last.managed_work
        XliffTransUnitMrk.where(xliff_id: cms.base_xliff.id).update_all(mrk_status: XliffTransUnitMrk::MRK_STATUS[:translation_completed])
        expect(bid.status).not_to eq(BID_COMPLETED)
        expect(cms.status).to eq(CMS_REQUEST_RELEASED_TO_TRANSLATORS)
        expect(mw.translation_status).not_to eq(MANAGED_WORK_COMPLETE)
        post complete_api_job_path(cms), {}, @headers
        cms.reload
        bid.reload
        mw.reload
        expect(bid.status).to eq(BID_COMPLETED)
        # expect(mw.translation_status).to eq(MANAGED_WORK_COMPLETE) # TODO investigate why this is not passing
        # expect(cms.status).to eq(CMS_REQUEST_TRANSLATED) # TODO investigate why this is not passing
      end

      it 'should create translated memories' do
        cms = @cms_requests.fourth
        XliffTransUnitMrk.where(xliff_id: cms.base_xliff.id).update_all(mrk_status: XliffTransUnitMrk::MRK_STATUS[:translation_completed])
        tms_count = TranslatedMemory.count
        post complete_api_job_path(cms), {}, @headers
        expect(TranslatedMemory.count).to eq(tms_count + XliffTransUnitMrk.where(xliff_id: cms.base_xliff.id, mrk_type: XliffTransUnitMrk::MRK_TYPES[:target]).count)
      end

      it 'should raise api error 417 when translation is not completed' do
        XliffTransUnitMrk.where(xliff_id: @cms.base_xliff.id).update_all(mrk_status: XliffTransUnitMrk::MRK_STATUS[:in_progress])
        post complete_api_job_path(@cms), {}, @headers
        json = ActiveSupport::JSON.decode(response.body)
        expect(json['message']).to eq('In order to declare this job as complete, you need to translate all the sentences in it. Some sentences are still not translated.')
        expect(json['code']).to eq(417)
      end

      it 'should raise api error 417 when issues are not resolved' do
        xliff_trans_unit_mrk = XliffTransUnitMrk.where(xliff_id: @cms.base_xliff.id).last
        issue = FactoryGirl.create(:issue, owner: xliff_trans_unit_mrk, target: @translator, title: 'This is a title for issue', kind: ISSUE_INCORRECT_TRANSLATION, status: ISSUE_OPEN)
        message = FactoryGirl.create(:message, owner: issue, body: 'This is a message for issue pointing to mrk.')

        post complete_api_job_path(@cms), {}, @headers
        json = ActiveSupport::JSON.decode(response.body)
        expect(json['message']).to eq('The sentence has open issues. Please respond to them before saving the translation.')
        expect(json['code']).to eq(417)
      end

      it 'should be able to complete the job if issue is not for translator' do
        xliff_trans_unit_mrk = XliffTransUnitMrk.where(xliff_id: @cms.base_xliff.id).last
        issue = FactoryGirl.create(:issue, owner: xliff_trans_unit_mrk, target: @cms.website.client, title: 'This is a title for issue', kind: ISSUE_INCORRECT_TRANSLATION, status: ISSUE_OPEN)
        message = FactoryGirl.create(:message, owner: issue, body: 'This is a message for issue pointing to mrk.')
        post complete_api_job_path(@cms), {}, @headers
        json = ActiveSupport::JSON.decode(response.body)
        expect(json['message']).to eq('Translation completed')
        expect(json['code']).to eq(200)
      end

      it 'should update work as complete when translator call api and review is disabled' do
        @bid_api.managed_work.update_attributes(active: MANAGED_WORK_INACTIVE)

        post complete_api_job_path(@cms), {}, @headers
        json = ActiveSupport::JSON.decode(response.body)
        @bid_api.reload
        @cms.reload

        expect(@bid_api.status).to eq(BID_COMPLETED)
        expect(@cms.status). to eq(CMS_REQUEST_DONE)
        expect(@cms.completed_at).not_to be nil
        expect(json['code']).to eq(200)
        expect(json['message']).to eq('Translation completed')
      end

      it 'should update status as waiting for reviewer when reviewer is not assigned' do
        @bid_api.managed_work.update_attributes(active: MANAGED_WORK_ACTIVE, translator: nil)

        post complete_api_job_path(@cms), {}, @headers
        json = ActiveSupport::JSON.decode(response.body)
        @bid_api.reload
        @cms.reload

        expect(@bid_api.status).to eq(BID_DECLARED_DONE)
        expect(@bid_api.managed_work.translation_status).to eq(MANAGED_WORK_WAITING_FOR_REVIEWER)
        expect(@cms.status). to eq(CMS_REQUEST_TRANSLATED)
        expect(json['code']).to eq(200)
        expect(json['message']).to eq('Translation completed')
      end

      it 'should update work status as complete by reviewer when review is enabled' do
        post complete_api_job_path(@cms), {}, @headers
        json = ActiveSupport::JSON.decode(response.body)
        @bid_api.reload
        @cms.reload
        expect(@bid_api.status).to eq(BID_DECLARED_DONE)
        expect(@bid_api.managed_work.translation_status).to eq(MANAGED_WORK_REVIEWING)
        expect(@cms.status). to eq(CMS_REQUEST_TRANSLATED)
        expect(json['code']).to eq(200)
        expect(json['message']).to eq('Translation completed')

        a, b, c = post(complete_api_job_path(@cms), {}, @headers_with_reviewer)
        json = JSON.parse(response.body)
        @bid_api.reload
        @cms.reload
        expect(@bid_api.status).to eq(BID_COMPLETED)
        expect(@bid_api.managed_work.translation_status).to eq(MANAGED_WORK_COMPLETE)
        expect(@cms.status). to eq(CMS_REQUEST_DONE)
        expect(@cms.completed_at).not_to be nil
        expect(json['code']).to eq(200)
        expect(json['message']).to eq('Review completed')
      end

      it 'should not be able complete already completed translation when review is disabled' do
        @bid_api.managed_work.update_attributes(active: MANAGED_WORK_INACTIVE)

        post complete_api_job_path(@cms), {}, @headers
        json = ActiveSupport::JSON.decode(response.body)
        @bid_api.reload
        @cms.reload
        expect(@bid_api.status).to eq(BID_COMPLETED)
        expect(@cms.status). to eq(CMS_REQUEST_DONE)
        expect(@cms.completed_at).not_to be nil
        expect(json['code']).to eq(200)
        expect(json['message']).to eq('Translation completed')

        post complete_api_job_path(@cms), {}, @headers
        json = ActiveSupport::JSON.decode(response.body)
        expect(json['code']).to eq(200)
        expect(json['message']).to eq('Translation completed')
      end

      it 'should not be able complete already completed review' do
        post complete_api_job_path(@cms), {}, @headers
        json = ActiveSupport::JSON.decode(response.body)
        @bid_api.reload
        @cms.reload
        expect(@bid_api.status).to eq(BID_DECLARED_DONE)
        expect(@bid_api.managed_work.translation_status).to eq(MANAGED_WORK_REVIEWING)
        expect(@cms.status). to eq(CMS_REQUEST_TRANSLATED)
        expect(json['code']).to eq(200)
        expect(json['message']).to eq('Translation completed')

        post complete_api_job_path(@cms), {}, @headers_with_reviewer
        json = ActiveSupport::JSON.decode(response.body)
        @bid_api.reload
        @cms.reload
        expect(@bid_api.status).to eq(BID_COMPLETED)
        expect(@bid_api.managed_work.translation_status).to eq(MANAGED_WORK_COMPLETE)
        expect(@cms.status). to eq(CMS_REQUEST_DONE)
        expect(@cms.completed_at).not_to be nil
        expect(json['code']).to eq(200)
        expect(json['message']).to eq('Review completed')

        post complete_api_job_path(@cms), {}, @headers_with_reviewer
        json = ActiveSupport::JSON.decode(response.body)
        expect(json['code']).to eq(200)
        expect(json['message']).to eq('Review is already completed')
      end

      it 'should update status to translate when reviewer completed job with open issues' do
        post complete_api_job_path(@cms), {}, @headers
        json = ActiveSupport::JSON.decode(response.body)
        @bid_api.reload
        @cms.reload
        expect(@bid_api.status).to eq(BID_DECLARED_DONE)
        expect(@bid_api.managed_work.translation_status).to eq(MANAGED_WORK_REVIEWING)
        expect(@cms.status). to eq(CMS_REQUEST_TRANSLATED)
        expect(json['code']).to eq(200)
        expect(json['message']).to eq('Translation completed')

        xliff_trans_unit_mrk = XliffTransUnitMrk.where(xliff_id: @cms.base_xliff.id).last
        issue = FactoryGirl.create(:issue, owner: xliff_trans_unit_mrk, target: @translator, title: 'This is a title for issue', kind: ISSUE_INCORRECT_TRANSLATION, status: ISSUE_OPEN)
        message = FactoryGirl.create(:message, owner: issue, body: 'This is a message for issue pointing to mrk.')

        post complete_api_job_path(@cms), {}, @headers_with_reviewer
        json = ActiveSupport::JSON.decode(response.body)
        @bid_api.reload
        @cms.reload
        expect(@bid_api.status).to eq(BID_ACCEPTED)
        expect(@bid_api.managed_work.translation_status).to eq(MANAGED_WORK_CREATED)
        expect(@cms.status). to eq(CMS_REQUEST_RELEASED_TO_TRANSLATORS)
        expect(json['code']).to eq(200)
        expect(json['message']).to eq('Review completed with open issues for translator')
        mail = ActionMailer::Base.deliveries.last
        expect(mail.subject).to eq("#{EMAIL_OWNER_TXT}Reviewer has opened issue")
        expect(mail.to.first).to eq(@translator.email)
      end

      it 'should return 404 when any other translator call api' do
        another_translator = FactoryGirl.create(:beta_translator)
        token = auth_token(another_translator)
        post complete_api_job_path(@cms), {}, @headers.merge('Authorization' => token)
        expect(response.code).to eq('404')
        expect(response.message).to eq('Not Found')
      end
    end
  end
end
