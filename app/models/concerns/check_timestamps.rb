module Concerns
  module CheckTimestamps
    extend ActiveSupport::Concern

    @@loger = Logger.new("log/timestamps.log")
    included do |base|
      base.after_save :fix_timestamps
    end

    def fix_timestamps
      begin
        if defined?(self.created_at) && defined?( self.created_at=() ) && self.created_at.nil?
          if self.created_at_changed? && !self.created_at_was.nil?
            self.update_column(:created_at, self.created_at_was)
            @@loger.error("Attempt to set created at to nil for model: #{self.class} and record #{self.id}")
          else
            self.update_column(:created_at, Time.now)
          end
        end

        if defined?(self.updated_at) && defined?( self.updated_at=() ) && self.updated_at.nil?
          if self.updated_at_changed? && !self.updated_at_was.nil?
            self.update_column(:updated_at, self.updated_at_was)
          else
            self.update_column(:updated_at, Time.now)
          end
        end
      rescue => e
        @@loger.error("Exception when trying to fix timestamps. #{e}, #{e.inspect}, #{e.to_s}")
      end
    end

  end
end