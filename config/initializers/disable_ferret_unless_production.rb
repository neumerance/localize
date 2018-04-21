unless Rails.env.production?
  module ActsAsFerret
    module ActMethods
      def acts_as_ferret(_options = {})
        Rails.logger.info 'Disabled acts_as_ferret'
      end
    end
  end
end
