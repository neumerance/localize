class Api
  def quote(file)
    begin
      raise "#{file} is not an uploaded file" if file.nil?
      extension = File.extname(file.original_filename)
      data =
        if file.respond_to?(:read)
          file.read
        elsif file.respond_to?(:path)
          File.read(file.path)
        else
          raise 'Invalid file'
        end

      if ZippedFile.extensions.include?(extension)
        text = ZippedFile.new(uploaded_data: file).text
        @format = ZippedFile.format_name_for(extension)
        @words = text.count_words
      else
        # TODO: Refac: extract to method
        case extension.downcase
        when '.properties'
          @words = try_formats([1], data)
        when '.po', '.pot'
          @words = try_formats([4, 11, 15], data)
        when '.xml'
          @words = try_formats([11, 13], data)
        when '.strings'
          @words = try_formats([3, 12], data)
        when '.res'
          @words = try_formats([2], data)
        when '.php'
          @words = try_formats([5, 6, 13], data)
        when '.plist'
          @words = try_formats([9, 10], data)
        else
          @words = try_formats([5, 10, 12], data)
        end
      end

      if @words > 1
        @quote = @words * MINIMUM_BID_AMOUNT
        @status = 'success'
      else
        @words = -1
        @quote = -1
        @status = 'fail'
        @message = "Sorry, we don't know how to read your file."
      end

    rescue => e
      Rails.logger.error e
      Rails.logger.error e.backtrace.join("\n")
      @status = 'error'
    end
    # Must convert @quote to Float because the Json encoder converts all
    # BigDecimal numbers to strings and we don't want that.
    { status: @status, wordCount: @words, quote: @quote.to_f,
      message: @message, fileType: @format }
  end

  private

  # TODO: Needs refact
  def try_formats(formats, text)
    ResourceFormat.find(formats).each do |resource_format|
      strings = resource_format.extract_texts(text)
      if strings.any?
        @format = resource_format.name
        return strings.inject(0) { |a, b| a + b[:text].count_words }
      end
    end
    0
  end
end
