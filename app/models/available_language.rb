class AvailableLanguage < ApplicationRecord
  belongs_to :from_language, class_name: 'Language', foreign_key: :from_language_id
  belongs_to :to_language, class_name: 'Language', foreign_key: :to_language_id

  def price_for(user)
    if user && user.top
      amount.to_f * TOP_CLIENT_DISCOUNT
    else
      amount.to_f
    end
  end

  def self.price_per_word_for(from_language, to_language)
    AvailableLanguage.find_by(from_language_id: from_language.id, to_language_id: to_language.id).amount
  end

  def self.regenarate(skip_scanned_check = false)
    res = "------ REGENERATE: START\n"
    # --- Step 1: pass through all languages that are not updated and verify that each has a translator
    languages = Language.includes(:available_language_froms).where('scanned_for_translators = 0')

    als_to_delete = []
    languages.each do |language|
      language.available_language_froms.each do |al|
        # check if there still is a translator for this language pair
        user_status = [1, 2].include?(al.qualified) ? USER_STATUS_QUALIFIED : USER_STATUS_REGISTERED

        translator = Translator.joins(:translator_language_froms, :translator_language_tos).
                     where("(users.userstatus= ?)
            AND (translator_languages.status =  ?)
            AND (translator_languages.language_id =  ?)
            AND (translator_language_tos_users.status =  ?)
            AND (translator_language_tos_users.language_id =  ?)",
                           user_status,
                           TRANSLATOR_LANGUAGE_APPROVED,
                           language.id,
                           TRANSLATOR_LANGUAGE_APPROVED,
                           al.to_language_id).first

        next if translator
        res += "no translator - deleting #{al.from_language_id}->#{al.to_language_id}\n"
        als_to_delete << al.id
        al.destroy
        # else
        # res += "got translator: #{translator.id}"
      end

      language.available_language_tos.each do |al|
        # check if there still is a translator for this language pair
        user_status = [1, 2].include?(al.qualified) ? USER_STATUS_QUALIFIED : USER_STATUS_REGISTERED

        translator = Translator.joins(:translator_language_froms, :translator_language_tos).
                     where("(users.userstatus= ?)
            AND (translator_languages.status =  ?)
            AND (translator_languages.language_id =  ?)
            AND (translator_language_tos_users.status =  ?)
            AND (translator_language_tos_users.language_id =  ?)",
                           user_status,
                           TRANSLATOR_LANGUAGE_APPROVED,
                           al.from_language_id,
                           TRANSLATOR_LANGUAGE_APPROVED,
                           language.id).first

        next if translator
        res += "no translator - deleting #{al.from_language_id}->#{al.to_language_id}\n"
        als_to_delete << al.id
        al.destroy
      end

      language.update_attributes(scanned_for_translators: 1)
    end

    unless als_to_delete.empty?
      res += "------ deleted these ALs: #{als_to_delete.join(',')}\n"
    end

    # --- Step 2: go through all unupdated translators and add their languages
    # translators = Translator.all
    # translators.each{|x|
    # res += "=== translator found: #{x.fname}. scanned_for_languages = #{x.scanned_for_languages}, userstatus = #{x.userstatus} \n"
    # }
    translators = if skip_scanned_check
                    Translator.where('(userstatus IN (?))', [USER_STATUS_QUALIFIED, USER_STATUS_REGISTERED])
                  else
                    Translator.where('(scanned_for_languages=0) AND (userstatus IN (?))', [USER_STATUS_QUALIFIED, USER_STATUS_REGISTERED])
                  end
    translators.each do |translator|
      res += "=== checking user #{translator.full_name} - #{translator.email} ==="
      translator.translator_language_froms.where(status: TRANSLATOR_LANGUAGE_APPROVED).find_each do |tlf|
        translator.translator_language_tos.where(status: TRANSLATOR_LANGUAGE_APPROVED).find_each do |tlt|

          qualified = translator.userstatus == USER_STATUS_QUALIFIED ? 1 : 0
          next if AvailableLanguage.where('(from_language_id=?) AND (to_language_id=?) AND (qualified=?)', tlf.language_id, tlt.language_id, qualified).first
          al = AvailableLanguage.new(from_language_id: tlf.language_id, to_language_id: tlt.language_id, qualified: qualified, amount: MINIMUM_BID_AMOUNT)
          al.save!
          res += "--> added translation language from #{tlf.language.name} to #{tlt.language.name} (qualified=#{qualified}), due to translator #{translator.email}\n"
          # else
          # res += "==> translation language from #{tlf.language.name} to #{tlt.language.name} already exists\n"
        end
      end
      # logger.info "---- indicating scanned_for_languages=1"
      translator.update_attribute(:scanned_for_languages, 1)
    end

    res += "------ REGENERATE: END\n"
    res
  end

end
