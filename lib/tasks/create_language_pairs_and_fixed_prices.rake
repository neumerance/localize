# This task will only run once: when the LanguagePairFixedPrice model is
# deployed to production. Calling it again will have no effect as all attempts
# to create language pairs (which will already exist) will fail the model's
# uniqueness validation.
#
# This task should take a couple of minutes to run.
desc 'Populate the table corresponding to the LanguagePairFixedPrice model'
task create_language_pairs_and_fixed_prices: :environment do
  languages = Language.all
  languages.each do |language_a|
    languages.each do |language_b|
      LanguagePairFixedPrice.create(
        from_language: language_a,
        to_language: language_b
      )
    end
  end
end
