module Users
  module UserSource
    def find_user_source(source)
      return nil if source.blank?

      segments = source.downcase.split('/').reverse
      segments.each do |segment|
        if segment.index('drupal')
          return('drupal')
        elsif segment.index('wordpress')
          return('wordpress')
        elsif segment.index('iphone')
          return('iphone')
        elsif segment.index('android')
          return('android')
        elsif segment.index('affiliate') || segment.index('partner')
          return('affiliate')
        elsif segment.index('software') || segment.index('resource')
          return('software')
        elsif segment.index('html')
          return('html')
        elsif segment.index('manual') || segment.index('hm')
          return('hm')
        elsif segment.index('general')
          return('general')
        end
      end

      nil
    end
  end
end
