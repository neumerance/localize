require File.dirname(__FILE__) + '/../test_helper'

class GlossaryTermTest < ActiveSupport::TestCase
  # Replace this with your real tests.

  TEST_TEXT = "When you click on Home you want to get to the home page in the language you're browsing. WPML 1.7.1 now makes this happens as it automatically adjusts the home page link to the correct language.
Before this version, you either had to edit your theme and use WPML's API function to get to the correct home URL, or it just went to the default language. Now, WPML does this for you.
For 99% of WordPress themes (the ones that use WP calls to get the home URL and don't just send you to '/'), WPML now adjusts the home-page URL according to the current language.
Language switcher upgrades
The language switcher got two handy additions in this release:
   1. The widget can display as a drop-down list or as an open list of languages.
   2. WPML can display a title for the widget (Languages).
We found that these two additions make WPML's language switcher display better for some themes, where the drop-down menu doesn't fit in.
Other changes this release
There aren't any major new bells and whistles, just a lot of work under the surface.
We've fixed about a dozen bugs such as galleries getting images from the wrong page, sub-pages not displaying correctly (in some configurations) and WPMU issues. You can see the full list in WPML's change log.
We've also added WPML's .po file to the locale directory so if you want to translate WPML itself to a different language, feel free to use that file.".freeze

  def test_find_frequent_words
    res = GlossaryTerm.find_frequent_words(TEST_TEXT)
    assert_equal %w(wpml language), res
    # res.each { |r| puts r }
  end

end
