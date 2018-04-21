require 'aws-sdk'

class BackupSender
  def self.send(bucket_name, fname, content, metadata = {})
    object = Aws::S3::Object.new(bucket_name, fname)
    object.put(body: content, metadata: metadata)
  end
end
