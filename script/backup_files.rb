models = [Attachment, Download, Image, WebAttachment, Xliff, ZippedFile]
models.each do |model|
  model.find_in_batches(conditions: ['backup_on_s3 = ?', true]) do |files|
    files.each(&:send_to_s3)
  end
  sleep(30)
end
