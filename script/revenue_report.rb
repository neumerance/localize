#   This script generates a report of revenue
#
#   ./script/runner ./script/revenue_report.rb
#
#   on server run with
#
#   ./script/runner -e production ./script/revenue_report.rb

require 'rubygems'
require 'awesome_print'
require 'colorize'
# require 'pry'

def account_info(account)
  if account.class == BidAccount
    revision = account.bid.try(:chat).try(:revision)
    'CmsRequest' if revision && revision.cms_request
  elsif account.class == UserAccount
    account.user.class.to_s
  else
    'Other'
  end
end

def mt_info(mt)
  puts '------------- '
  puts "id: #{mt.id}"
  puts "Operation Code: #{mt.operation_code} #{@operation_codes[mt.operation_code]}"
  puts "Fee Ammount: #{mt.fee}"
  puts 'Transfer from %s#%s ===> %s#%s' % [mt.source_account.class.to_s, account_info(mt.source_account),
                                           mt.target_account.class.to_s, account_info(mt.target_account)]
end

@operation_codes = {
  1 => 'TRANSFER_DEPOSIT_TO_BID_ESCROW',
  2 => 'TRANSFER_PAYMENT_FROM_BID_ESCROW',
  3 => 'TRANSFER_REFUND_FROM_BID_ESCROW',
  4 => 'TRANSFER_DEPOSIT_FROM_EXTERNAL_ACCOUNT',
  5 => 'TRANSFER_PAYMENT_TO_EXTERNAL_ACCOUNT',
  6 => 'TRANSFER_REVERSAL_OF_PAYMENT_TO_EXTERNAL_ACCOUNT',
  7 => 'TRANSFER_FEE_FROM_TRANSLATOR',
  8 => 'TRANSFER_PAYMENT_FOR_INSTANT_TRANSLATION',
  9 => 'TRANSFER_PAYMENT_FOR_TA_RENTAL',
  10 => 'TRANSFER_DEPOSIT_TO_RESOURCE_TRANSLATION',
  11 => 'TRANSFER_PAYMENT_FROM_RESOURCE_TRANSLATION',
  12 => 'TRANSFER_REFUND_FOR_RESOURCE_TRANSLATION',
  15 => 'TRANSFER_PAYMENT_FROM_RESOURCE_REVIEW',
  17 => 'TRANSFER_DEPOSIT_TO_RESOURCE_TRANSLATION_WITH_REVIEW',
  18 => 'TRANSFER_DEPOSIT_TO_RESOURCE_REVIEW',
  20 => 'TRANSFER_DEPOSIT_TO_PROJECT_REVIEW',
  22 => 'TRANSFER_DEPOSIT_FOR_SERVICE_WORK',
  23 => 'TRANSFER_GENERAL_REFUND',
  24 => 'TRANSFER_PAYMENT_FROM_KEYWORD_LOCALIZATION',
  25 => 'TRANSFER_DEPOSIT_TO_RESOURCE_TRANSLATION_WITH_REVIEW_AND_KEYWORDS',
  26 => 'TRANSFER_DEPOSIT_TO_RESOURCE_REVIEW_WITH_KEYWORDS',
  27 => 'TRANSFER_DEPOSIT_TO_RESOURCE_KEYWORDS',
  28 => 'TRANSFER_REUSE_KEYWORD',
  29 => 'TRANSFER_MANUAL_TO_SYSTEM_ACCOUNT',
  30 => 'TRANSFER_TAX_RATE'
}

puts 'Revenue Report'.yellow

@results = { software: 0, bidding: 0, cms: 0, instant_translation: 0, keyword: 0, ignored: 0, others: 0 }

root_account = RootAccount.first
money_transactions = root_account.money_transactions.
                     where('status = ? AND fee_rate > 0', TRANSFER_COMPLETE).
                     order('id DESC').
                     limit(1000)

valid_codes = [
  TRANSFER_PAYMENT_FROM_BID_ESCROW,
  TRANSFER_PAYMENT_FOR_INSTANT_TRANSLATION,
  TRANSFER_PAYMENT_FROM_BID_ESCROW,

  TRANSFER_REUSE_KEYWORD, # not sure if this is valid
]
ignore_codes = [
  TRANSFER_PAYMENT_FOR_TA_RENTAL, # free for private translators
]
codes_group = {
  bidding: [
    TRANSFER_PAYMENT_FROM_BID_ESCROW,
    TRANSFER_DEPOSIT_TO_BID_ESCROW # not sure about this
  ],
  software: [TRANSFER_PAYMENT_FROM_RESOURCE_REVIEW, TRANSFER_PAYMENT_FROM_RESOURCE_TRANSLATION],
  keyword: [TRANSFER_REUSE_KEYWORD, TRANSFER_PAYMENT_FROM_KEYWORD_LOCALIZATION]
}

pending = []
ignored = []
money_transactions.each do |mt|
  project_kind = :others
  ignore = false

  ignore = true if ignore_codes.include? mt.operation_code
  if mt.source_account.class == UserAccount && mt.target_account.class == UserAccount
    ignore = true if mt.source_account.user.class == Client && mt.target_account.user.class == Client
  end

  if ignore
    project_kind = :ignored
    ignored << mt
  else

    # Cms
    if mt.source_account.class == BidAccount && codes_group[:bidding].include?(mt.operation_code)
      revision = mt.source_account.bid.try(:chat).try(:revision)
      if revision
        project_kind = if revision.cms_request_id
                         :cms
                       else
                         # Bidding
                         :bidding
                       end
      end

    end

    # Software
    if (mt.owner_type == 'StringTranslation') && codes_group[:software].include?(mt.operation_code)
      project_kind = :software
    end

    # Instant Translations
    if (mt.owner_type == 'WebMessage') && (mt.operation_code == TRANSFER_PAYMENT_FOR_INSTANT_TRANSLATION)
      project_kind = :instant_translation
    end

    # Keyword
    # @ToDo this should calculate to the parent project?
    project_kind = :keyword if codes_group[:keyword].include? mt.operation_code

  end

  @results[project_kind] += mt.fee

  pending << mt if project_kind == :others
end

puts '==========================='
puts '========= PENDING ========='
puts ''
pending.each { |i| mt_info(i) } unless pending.empty?
3.times { puts '' }
puts '==========================='
puts '========= IGNORED ========='
ignored.each { |i| mt_info(i) } unless ignored.empty?

puts ''
puts "total: #{money_transactions.size}"
puts "pending: #{pending.size}"
puts "ignored: #{ignored.size}"
puts ''

ap @results

exit
