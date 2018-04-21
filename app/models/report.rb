class Report
  def self.campaing_report_data(from, to)
    results = CampaingTrack.where(['created_at > ? and created_at < ?', from, to])
    data = "Alerts triggered;#{results.find_all { |x| x.state == 0 }.size}\n"
    data += "Clicked in the links;#{results.find_all { |x| x.state == 1 }.size}\n"
    data += "Invite a translator;#{results.find_all { |x| x.state == 2 }.size}\n"

    data
  end

  def self.money_per_project_raw_data(from, to, user)
    # Money from client -> escrow from all client projects
    money_account_ids = user.money_accounts.map(&:id)
    money_transactions = MoneyTransaction.includes(:target_account).where(['chgtime > ? and chgtime < ? and source_account_id in (?)', from, to, money_account_ids])
    money_per_project = {}
    money_transactions.each do |money_transaction|
      account = money_transaction.target_account_type.constantize.find_by_id(money_transaction.target_account_id)
      unless account.nil?
        case account.class.to_s
          when 'BidAccount'
            revision = account.bid.try(:chat).try(:revision)
            if revision
              if revision.cms_request
                money_per_project[revision.cms_request.website.name] ||= { to_escrow: 0, from_escrow: 0 }
                money_per_project[revision.cms_request.website.name][:to_escrow] += money_transaction.amount.to_f
              else
                money_per_project[revision.project.name] ||= { to_escrow: 0, from_escrow: 0 }
                money_per_project[revision.project.name][:to_escrow] += money_transaction.amount.to_f
              end
            else
              money_per_project['failed to track'] ||= { to_escrow: 0, from_escrow: 0 }
              money_per_project['failed to track'][:to_escrow] += money_transaction.amount.to_f
            end
          when 'ResourceLanguageAccount'
            money_per_project[account.resource_language.text_resource.name] ||= { to_escrow: 0, from_escrow: 0 }
            money_per_project[account.resource_language.text_resource.name][:to_escrow] += money_transaction.amount.to_f
          when 'UserAccount'
            unless money_transaction.operation_code == TRANSFER_PAYMENT_FOR_INSTANT_TRANSLATION
              raise "uncaugtch transaction? #{money_transaction.id}"
            end
            money_per_project['instant translation'] ||= { to_escrow: 0, from_escrow: 0 }
            money_per_project['instant translation'][:to_escrow] += money_transaction.amount.to_f
          when 'ExternalAccount'
            # money_per_project['retrieved to paypal/google/others'][:to_escrow] += money_transaction.amount.to_f
          when 'RootAccount'
            raise "Should not transfer directly to root account #{money_transaction.id} "
          else
            raise "Uncautch class: #{account.class}"
        end
      end
    end

    # Accounts from escrow->translator accounts for bidding and website projects
    project_money_accounts = Hash.new([])
    user.revisions.each do |revision|
      if revision.cms_request
        project_money_accounts[revision.cms_request.website.name] += revision.revision_languages.map { |b| b.try(:selected_bid).try(:account) }
      else
        project_money_accounts[revision.name] += revision.revision_languages.map { |b| b.try(:selected_bid).try(:account) }
      end
    end
    # Accounts from escrow->translator accounts for software projects
    user.text_resources.each do |text_resource|
      project_money_accounts[text_resource.name] += text_resource.resource_languages.map { |x| x.money_accounts.first }
    end

    # Count the money for revisions and text_resources
    project_money_accounts.each_pair do |proj_name, accounts|
      accounts.delete(nil)
      mts = []
      accounts.each do |account|
        mts += account.money_transactions.where('money_transactions.chgtime > ? and money_transactions.chgtime < ? and money_transactions.chgtime is not null and operation_code = ?', from, to, TRANSFER_PAYMENT_FROM_BID_ESCROW).all.to_a
      end
      money_per_project[proj_name] ||= { to_escrow: 0, from_escrow: 0 }
      money_per_project[proj_name][:from_escrow] += mts.inject(0) { |a, b| a + b.amount }
    end

    # Money from escrow -> instant translations
    mts = money_transactions.find_all { |x| x.operation_code == TRANSFER_PAYMENT_FROM_BID_ESCROW }
    if mts.any?
      money_per_project['instant translation'] ||= { to_escrow: 0, from_escrow: 0 }
      money_per_project['instant translation'][:from_escrow] = mts.inject(0) { |a, b| a + b.amount }
    end

    money_per_project
  end

  def self.money_per_project_data(from, to, user)
    money_per_project = money_per_project_raw_data(from, to, user)
    data = "Project name;Client->Escrow;Escrow->Translators\n"
    total1 = 0
    total2 = 0
    money_per_project.each_pair { |k, v| total1 += v[:to_escrow]; total2 += v[:from_escrow]; data << "#{k};#{v[:to_escrow]};#{v[:from_escrow]}\n" }
    data << "\n\nTotal client->escrow: #{total1}"
    data << "\n\nTotal escrow->translator: #{total2}"
    data
  rescue => e
    e.inspect + e.backtrace.join("\n")
  end

  def self.profit_loss_centers(from, to)
    user = User.find_by(id: 16) # Amir
    #todo refactor this, triggers 2 mil queries for 6 months report. emartini 3/03/2017
    money_per_project = money_per_project_raw_data(from, to, user)
    centers = { wpml: 0, icanlocalize: 0, toolset: 0 }

    centers[:wpml] += money_per_project['WPML'][:from_escrow] if money_per_project['WPML'].present?
    centers[:wpml] += money_per_project['WPML theme'][:from_escrow] if money_per_project['WPML theme'].present?
    centers[:wpml] += money_per_project['WPML themes demo'][:from_escrow] if money_per_project['WPML themes demo'].present?
    centers[:wpml] += money_per_project['WPML forum bank'][:from_escrow] if money_per_project['WPML forum bank'].present?
    centers[:wpml] += money_per_project['WPML banner text'][:from_escrow] if money_per_project['WPML banner text'].present?

    centers[:toolset] += money_per_project['WP Types and Views'][:from_escrow] if money_per_project['WP Types and Views'].present?

    centers[:icanlocalize] += money_per_project['icanlocalize.com'][:from_escrow] if money_per_project['icanlocalize.com'].present?
    centers[:icanlocalize] += money_per_project['ICanLocalize'][:from_escrow] if money_per_project['ICanLocalize'].present?

    data = "Profit/Loss center; Amount\n"
    centers.each_pair do |k, v|
      data << "#{k};#{v}\n"
    end
    data
  end

  def self.new_projects_count_data(from, to)
    bidding_count = Revision.count_by_sql(["SELECT count( distinct r.id ) FROM `revisions` as r
                                                            inner JOIN projects as p on r.project_id = p.id
                                                            inner join revision_languages as rl on r.id = rl.revision_id
                                                            inner join bids as b on rl.id = b.revision_language_id
                                                            inner join users as u on p.client_id = u.id
                                                           WHERE r.cms_request_id is null
                                                            and b.won = 1
                                                            and u.email != ?
                                                            and r.creation_time > ?
                                                            and r.creation_time < ?
                                        ", DEMO_CLIENT_EMAIL, from, to])


    websites_count = Website.count_by_sql(["SELECT COUNT( DISTINCT w.id ) FROM `websites`as w
                                                                            inner JOIN users as u on w.client_id = u.id
                                                                            inner JOIN money_accounts as m on u.id = m.owner_id
                                                                                      inner JOIN money_transactions as mt on m.id = mt.target_account_id
                                                                                  WHERE (w.created_at > ? and w.created_at < ?)
                                                                                    AND m.type='UserAccount'
                                                                                      AND mt.target_account_type='MoneyAccount'", from, to])

    software_count = Website.count_by_sql(["SELECT COUNT( DISTINCT t.id ) FROM `text_resources`as t
                                                                            inner JOIN users as u on t.client_id = u.id
                                                                            inner JOIN money_accounts as m on u.id = m.owner_id
                                                                                      inner JOIN money_transactions as mt on m.id = mt.target_account_id
                                                                                  WHERE (t.created_at > ? and t.created_at < ?)
                                                                                    AND m.type='UserAccount'
                                                                                      AND mt.target_account_type='MoneyAccount'", from, to])
    instant_count = WebMessage.where('create_time > ? and create_time < ?', from, to).count

    total = bidding_count + websites_count + software_count + instant_count

    "#{bidding_count} Bidding projects\n#{websites_count} Website projects\n#{software_count} Software projects\n#{instant_count} Instant translations\nTotal: #{total}"
  end

  def self.new_projects_data(from, to)
    data = ''
    data << "SOFTWARE PROJECTS\n"
    data << "name;url;from language;to languages\n"
    to_languages_count = Hash.new(0)
    from_languages_count = Hash.new(0)
    text_resources = TextResource.includes(:resource_languages).where(['created_at > ? and created_at < ?', from, to])
    text_resources.each do |tr|
      tr.resource_languages.each do |rl|
        to_languages_count[rl.language.name] += 1
      end
      from_languages_count[tr.language.name] += 1
      data << "#{tr.name};www.icanlocalize.com/text_resources/#{tr.id};#{tr.language.name};#{tr.resource_languages.map { |x| x.language.name }.join(', ')}\n"
    end
    data << "\n"
    data << "Number of times each language appears as source language:\n"
    from_languages_count.each_pair do |k, v|
      data << "#{k};#{v}\n"
    end

    data << "\n"
    data << "Number of times each language appears as target language:\n"
    to_languages_count.each_pair do |k, v|
      data << "#{k};#{v}\n"
    end

    data << "\n"
    data << "\n"
    data << "\n"

    data << "WEBSITES\n"
    data << "name;url;from language;to languages\n"
    to_languages_count = Hash.new(0)
    from_languages_count = Hash.new(0)
    websites = Website.includes(:website_translation_offers).where(['created_at > ? and created_at < ?', from, to])
    websites.each do |website|
      tls = website.website_translation_offers.map { |x| x.to_language.name }.uniq
      tls.each { |n| to_languages_count[n] += 1 }

      fls = website.website_translation_offers.map { |x| x.from_language.name }.uniq
      fls.each { |n| from_languages_count[n] += 1 }

      data << "#{escape_csv(website.name)};www.icanlocalize.com/websites/#{website.id};#{fls.join(', ')};#{tls.join(', ')}\n"
    end
    data << "\n"
    data << "Number of times each language appears as source language:\n"
    from_languages_count.each_pair do |k, v|
      data << "#{k};#{v}\n"
    end

    data << "\n"
    data << "Number of times each language appears as target language:\n"
    to_languages_count.each_pair do |k, v|
      data << "#{k};#{v}\n"
    end

    data << "\n"
    data << "\n"
    data << "\n"

    data << "Bidding Projects\n"
    data << "name;url;from language;to languages\n"
    to_languages_count = Hash.new(0)
    from_languages_count = Hash.new(0)
    revisions = Revision.where(['creation_time > ?', from])
    revisions.each do |rev|
      next unless rev.cms_request.nil? && rev.language && rev.project
      from_languages_count[rev.language.name] += 1
      tls = rev.bids.map { |x| x[1] }.flatten.find_all { |b| b.won == 1 }.map { |x| x.revision_language.language.name }
      if tls
        tls.each do |l|
          to_languages_count[l] += 1
        end
      end
      data << "#{rev.project.name};www.icanlocalize.com/projects/#{rev.project.id}/revisions/#{rev.id};#{rev.language.name};#{tls ? tls.join(', ') : ''}\n"
    end
    data << "\n"
    data << "Number of times each language appears as source language:\n"
    from_languages_count.each_pair do |k, v|
      data << "#{k};#{v}\n"
    end

    data << "\n"
    data << "Number of times each language appears as target language:\n"
    to_languages_count.each_pair do |k, v|
      data << "#{k};#{v}\n"
    end

    data << "\n"

    data
  end

  def self.money_deposits_data(from, to)
    days_diff = ((to - from) / 1.day).round
    day_header = days_diff > 1 ? 'Day Average' : 'Day Estimative'
    week_header = days_diff > 1 ? 'Week Average' : 'Week Estimative'
    month_header = days_diff > 1 ? 'Month Average' : 'Month Estimative'
    data = "Client;Deposited Amount;#{day_header};#{week_header};#{month_header}\n"

    money_per_client = deposited_money_per_client(from, to)
    money_per_client.each_pair do |client, amount|
      day_average = '%0.2f' % (amount.to_f / days_diff)
      week_average = '%0.2f' % (day_average.to_f * 7)
      month_average = '%0.2f' % (day_average.to_f * 30)
      data += "#{escape_csv(client)};#{amount};#{day_average};#{week_average};#{month_average}\n"
    end
    data
  end

  def self.money_spent_data(from, to)
    days_diff = ((to - from) / 1.day).round
    day_header = days_diff > 1 ? 'Day Average' : 'Day Estimative'
    week_header = days_diff > 1 ? 'Week Average' : 'Week Estimative'
    month_header = days_diff > 1 ? 'Month Average' : 'Month Estimative'
    data = "Client;SpentAmount;#{day_header};#{week_header};#{month_header}\n"

    money_per_client = spent_money_per_client(from, to)
    money_per_client.each_pair do |client, amount|
      day_average = '%0.2f' % (amount.to_f / days_diff)
      week_average = '%0.2f' % (day_average.to_f * 7)
      month_average = '%0.2f' % (day_average.to_f * 30)
      data += "#{escape_csv(client)};#{amount};#{day_average};#{week_average};#{month_average}\n"
    end
    data
  end

  private_class_method
  def self.escape_csv(text)
    text.gsub(/(\n|;|\r)/, '')
  end

  def self.deposited_money_per_client(from, to)
    money_transactions = MoneyTransaction.where(["chgtime > ? and chgtime < ? and
                                               operation_code = #{TRANSFER_DEPOSIT_FROM_EXTERNAL_ACCOUNT} ", from, to])

    money_per_client = Hash.new(0)
    money_transactions.each do |mt|
      next unless mt.target_account.respond_to? 'user'
      user = mt.target_account.user
      if user && user.has_client_privileges?
        money_per_client[user.nickname] += mt.amount.to_f
      end
    end
    money_per_client
  end

  def self.spent_money_per_client(from, to)
    money_transactions = ActiveRecord::Base.connection.exec_query("
      Select u.nickname, sum(mt.amount) as total
        from money_transactions as mt
          inner JOIN money_accounts as ma on mt.source_account_id = ma.id
          inner JOIN users as u on ma.owner_id = u.id
        where mt.chgtime > '#{from}' and mt.chgtime < '#{to}'
          and mt.operation_code in (#{MoneyTransaction.client_payment_codes.join(",")})
          and mt.source_account_type = 'MoneyAccount'
          and ma.type = 'UserAccount'
          and u.type = 'Client'
        group by u.nickname
      ")
    money_per_client = {}
    money_transactions.each do |mt|
        money_per_client[mt['nickname']] = mt['total']
    end
    money_per_client
  end

  def self.website_projects_report

  end
end
