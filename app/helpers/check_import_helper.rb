module CheckImportHelper
  def remove_tags(input)
    input.gsub(/<.*?>/, '')
  end
end
