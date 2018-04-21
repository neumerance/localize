#   usage:
#    bundle exec rails runner ./script/po/change_tokens_to_support_msgctxt.rb
#
#   This script converts the token of ResourceStrings to include the msgctxt
#
#   icldev-1253 .po strings with 2nd parameter "context" not recognized within ICL
#   icldev-1837 Convert msgctxt migration to script

class ChangeTokensToSupportMsgctxt
  include CharConversion

  def initialize
    puts "START: Convert RS token to include msgctxt start "

    uploads = ResourceUpload.\
              joins(:resource_upload_format).\
              where('resource_upload_formats.resource_format_id = 4').\
              map { |ru| ru if ru.get_contents.try :include?, 'msgctxt' }.\
              reject(&:blank?)

    puts "#{uploads.count} files to process"

    changes = {}

    count = 0
    uploads.each do |ru|
      count += 1
      puts " file #{count} of #{uploads.count} "
      begin
        decoded_src = unencode_string(ru.get_contents, ru.resource_format.encoding)

        old_tokens_for(decoded_src).each do |old_token, new_token|
          targets = ru.text_resource.resource_strings.where(token: old_token)
          targets.each { |rs| changes[rs.id] = rs.token }
          # targets.update_all token: new_token
          # puts "#{old_token} -> #{new_token}"
        end
      rescue => e
        puts "  ERROR: ResourceUpload##{ru.id}: #{e.message}"
        changes[:error] ||= {}
        changes[:error][ru.id] = e.message
      end
    end

    open(Rails.root.join('log', 'msgctxt_migration.yml'), 'w') { |f| YAML.dump(changes, f) }
  end

  def old_tokens_for(decoded_src)
    tokens = {}

    translations = GetPomo::PoFile.parse(decoded_src)
    puts "  - #{translations.count} strings found"      

    translations.each do |translation|
      next if translation.header?

      new_token = new_token_for_translation translation

      if translation.plural?
        tokens[Digest::MD5.hexdigest(translation.msgid[0].to_s)] = new_token[0]
        tokens[Digest::MD5.hexdigest(translation.msgid[1].to_s)] = new_token[1]
      else
        tokens[Digest::MD5.hexdigest(translation.msgid.to_s)] = new_token
      end
    end

    tokens
  end

  def new_token_for_translation(translation)
    base = ''

    base << translation.msgctxt if translation.msgctxt

    if translation.plural?
      [0, 1].map { |i| Digest::MD5.hexdigest(base + translation.msgid[i].to_s) }
    else
      Digest::MD5.hexdigest(base + translation.msgid.to_s)
    end
  end
end

ChangeTokensToSupportMsgctxt.new
