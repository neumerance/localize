require File.dirname(__FILE__) + '/../test_helper'

class CmsTermTest < ActiveSupport::TestCase
  fixtures :languages, :websites, :users, :cms_terms, :cms_term_translations

  def test_kids
    english = languages(:English)
    spanish = languages(:Spanish)
    german = languages(:German)

    term = cms_terms(:amir_wp_page1)
    assert term
    assert_equal english, term.language
    assert_equal 3, term.children.length
    term.children.each do |child|
      assert_equal term, child.parent
    end
    assert_equal 2, term.cms_term_translations.length
    assert_equal spanish, term.cms_term_translations[0].language
    assert_equal german, term.cms_term_translations[1].language

  end
end
