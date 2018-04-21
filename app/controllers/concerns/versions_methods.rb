module VersionsMethods
  def auto_complete_version(existing_version, user)
    revision = existing_version.revision

    # begin
    version = ::Version.create!(chgtime: Time.now, description: 'Created by version completer', filename: existing_version.filename, by_user_id: user.id, size: 1, content_type: existing_version.content_type)

    FileUtils.mkdir_p(File.dirname(version.full_filename))

    vc = VersionCompleter.new(existing_version, logger)
    vc.read
    language_names = existing_version.revision.revision_languages.collect { |rl| rl.language.name }
    vc.complete_languages(language_names)

    Zlib::GzipWriter.open(version.full_filename) do |gz|
      vc.write(gz)
    end

    version.size = File.size(version.full_filename)
    version.save!

    created_ok = true
    # rescue ActiveRecord::RecordInvalid
    # @result = {"message" => "Version failed"}
    # end

    if created_ok
      # add this version to the revision
      # indicate that this version was posted by this user
      version.revision = revision
      version.user = user
      version.save!
    end

    if created_ok
      unless version.update_statistics(user)
        version.destroy
        @result = { 'message' => "Version doesn't contain text" }
        created_ok = false
      end
    end

    if created_ok
      send_output_notification(version, user)
      revision.count_track
      revision.update_attributes!(update_counter: revision.update_counter + 1)
    end

    version
  end
end
