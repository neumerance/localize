require 'rails_helper'

describe Issue do
  context 'validations' do
    shared_examples 'has_base_validation_error' do
      it 'has validation error' do
        issue.valid?
        expect(issue.errors[field].first).to eq(message)
      end
    end

    context 'investigate created_at' do
      let(:issue) { create(:issue) }
      it 'should have created at' do
        expect(issue.created_at.present?).to eq(true)
      end
    end

    context 'presence' do
      %w(initiator_id target_id kind status owner_id owner_type title).each do |field|
        let(:issue) { build(:issue, field.to_sym => nil) }
        let(:message) { 'can\'t be blank' }
        let(:field) { field.to_sym }
        include_examples 'has_base_validation_error'
      end
    end

    context 'kind and target selection' do
      %w(target_id kind).each do |field|
        let(:issue) { build(:issue, field.to_sym => 0) }
        let(:message) { 'not selected' }
        let(:field) { field.to_sym }
        include_examples 'has_base_validation_error'
      end
    end
  end

  context 'callbacks' do
    it 'should trigger tp notification when issue is closed' do
      issue = FactoryGirl.create(:issue, status: ISSUE_OPEN)
      issue.status = ISSUE_CLOSED
      expect(issue).to receive(:notify_tp_issue_closed)
      issue.save
    end

    it 'should not trigger tp notification when other field is changed' do
      issue = FactoryGirl.create(:issue, status: ISSUE_OPEN)
      issue.tp_callback_url = ''
      issue.title = 'Some title'
      expect(issue).not_to receive(:notify_tp_issue_closed)
      issue.save
    end
  end
end
