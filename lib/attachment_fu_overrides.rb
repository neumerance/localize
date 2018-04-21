module AttachmentFuOverrides
  HierarchyLevels = 2
  ConnectionEstablished = false

  def full_filename(thumbnail = nil)
    file_system_path = (thumbnail ? thumbnail_class : self).attachment_options[:path_prefix].to_s
    parts = [Rails.root, file_system_path] +
            (1..HierarchyLevels).map { |i| partial_path(i) } +
            [attachment_path_id.to_s, thumbnail_name_for(thumbnail).to_s]
    File.join(parts)
  end

  def attachment_data
    current_data
  end

  protected

  # Given i, extract the ith 8-bit hex representation from our primary id.
  def partial_path(i)
    '%02X' % (attachment_path_id.to_i >> (8 * i)) % 256
  end
end
