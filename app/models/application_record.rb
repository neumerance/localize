class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
  include Concerns::CheckTimestamps

  # this method can be used in a model to transparently keep a filed Base64 encoded in DB
  # DO NOT ADD THIS METHOD TO A MODEL THAT ALREADY CONTAINS DATA without creating a migration to encode existing data first
  # This also decrease the performance, so do not use it on records that are accessed often or in in large batches
  def self.acts_as_encoded(*attributes)
    self.class_eval do
      attributes.each do |attribute|
        attr_accessor "#{attribute}_encoded".to_sym
      end
      before_save ActsAsEncoded::EncoderWrapper.new(attributes)
      after_save ActsAsEncoded::EncoderWrapper.new(attributes)
      after_find do
        ActsAsEncoded::EncoderWrapper.after_find(self, attributes)
      end
    end
  end

end
