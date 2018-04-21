require 'base64'

module ActsAsEncoded
  class EncoderWrapper

    def initialize(attributes)
      @attributes_hash = {}
      attributes.each do |attribute|
        attribute = attribute.to_s
        @attributes_hash[attribute] = {
          get_method: attribute,
          set_method: attribute + '='
        }
      end
    end

    def before_save(record)
      encode(record)
    end

    def after_save(record)
      decode(record)
    end

    def self.after_find(record, attributes)
      attributes.each do |a|
        a = a.to_s
        if record.respond_to?(a + '_encoded')
          next if record.send(a).nil?
          record.send(a + '=', Base64.decode64(record.send(a)).force_encoding('UTF-8'))
        end
      end
    end

    private

    def encode(record)
      @attributes_hash.each do |k, v|
        next if record.send(k).nil?
        record.send(v[:set_method], Base64.encode64(record.send(v[:get_method])))
      end
    end

    def decode(record)
      @attributes_hash.each do |k, v|
        next if record.send(k).nil?
        record.send(v[:set_method], Base64.decode64(record.send(v[:get_method])).force_encoding('UTF-8'))
      end
    end

  end
end
