class Newsletter < ApplicationRecord
  validates_presence_of :subject, :body, :flags
  validates :body, length: { maximum: COMMON_NOTE }

  has_many :text_results, as: :owner, dependent: :destroy

  default_scope { order('id DESC') }

  DEFAULT_TEST_EMAILS = ['irina.s@icanlocalize.com', 'laura.d@icanlocalize.com', 'ornela.f@icanlocalize.com'].freeze

  # TODO: This method need some refactoring -jonjon 05162017
  def body_markup(main)
    cache_key = "markup.main=#{main}"

    text_result = text_results.find_by(kind: cache_key)
    if text_result.present?
      return text_result.txt unless text_result.txt.blank?
    end

    txt = nil
    begin
      txt = parse_newsletter_body
      logger.debug txt

      sub = (main ? 2 : 1)
      for i in [3, 2, 1]
        h_from = "<h#{i}>"
        h_to = "<h#{i + sub}>"
        txt = txt.gsub(h_from, h_to)
        h_from = "</h#{i}>"
        h_to = "</h#{i + sub}>"
        txt = txt.gsub(h_from, h_to)
      end

      if main
        brk_idx = txt.index('<!--break-->')
        unless brk_idx.nil?
          txt = txt[0...brk_idx] + "<a style=\"read_next\" href=\"/newsletters/show/#{id}#more\">Continue reading</a></p>" # the P tag was opened by BlueCloth
        end
      else
        # replace the break with an anchor
        txt = txt.gsub('<!--break-->', '<a name="more"></a>')
      end
    rescue => e
      logger.debug "RESCUED!!! #{e.inspect}"
      res = body.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;').gsub('"', '&quot;').gsub("\n", '<br />')
    end

    logger.debug '================='
    logger.debug txt
    text_results.delete_all
    text_result = TextResult.new(txt: txt, kind: cache_key)
    text_result.owner = self
    text_result.save!

    txt
  end

  def body_plain
    cache_key = 'body_plain'

    text_result = text_results.find_by(kind: cache_key)
    return text_result.txt if text_result

    # remove the break indication
    txt = body.gsub('<!--break-->', '')

    # remove index tags
    cont = true
    while cont
      img_idx = txt.index('<img')
      end_idx = txt.index('/>')
      if !img_idx.nil? && !end_idx.nil? && (end_idx > img_idx)
        txt = txt[0...img_idx] + txt[(end_idx + 2)..-1]
      else
        cont = false
      end
    end

    text_result = TextResult.new(txt: txt, kind: cache_key)
    text_result.owner = self
    text_result.save!

    txt
  end

  def target_users
    if (flags & NEWSLETTER_FOR_TRANSLATORS) == NEWSLETTER_FOR_TRANSLATORS
      logger.info '-------- checking for translators'
      return Translator.where('(users.userstatus IN (?)) AND ((users.notifications & ?) != 0)', [USER_STATUS_REGISTERED, USER_STATUS_QUALIFIED], NEWSLETTER_NOTIFICATION)
    elsif (flags & NEWSLETTER_FOR_CLIENTS) == NEWSLETTER_FOR_CLIENTS
      logger.info '-------- checking for clients'
      if !sql_filter.blank?
        return Client.includes(:websites, :projects, :web_supports, :web_messages, :text_resources).
               where("(users.userstatus = #{USER_STATUS_REGISTERED}) AND ((users.notifications & #{NEWSLETTER_NOTIFICATION}) != 0) AND (users.anon != 1) AND (#{sql_filter})")
      else
        return Client.where('(users.userstatus = ?) AND ((users.notifications & ?) != 0) AND (users.anon != 1)', USER_STATUS_REGISTERED, NEWSLETTER_NOTIFICATION)
      end
    end
    logger.info "-------- not checking for anyone. flags=#{flags}, flags & NEWSLETTER_PENDING_FOR_CLIENTS_MASK=#{flags & NEWSLETTER_PENDING_FOR_CLIENTS_MASK}"
    []
  end

  private

  require 'bluecloth'

  def parse_newsletter_body
    BlueCloth.new(body).to_html
  rescue
    BlueCloth.new(body.encode('Windows-31J')).to_html
  end
end
