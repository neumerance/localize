require "#{File.dirname(__FILE__)}/../test_helper"

class CmsTermsTest < ActionDispatch::IntegrationTest
  fixtures :users, :websites, :languages, :cms_terms, :cms_term_translations

  def test_tree_display
    english = languages(:English)
    spanish = languages(:Spanish)
    german = languages(:German)

    client = users(:amir)
    session = login(client)

    term = cms_terms(:amir_wp_page1)
    website = term.website

    [nil, 1].each do |show_translation|
      [nil, 1].each do |show_children|
        # puts "\n----------- show_translation: #{show_translation}, show_children: #{show_children}"
        get(url_for(controller: :cms_terms, action: :show, website_id: website.id, id: term.id, format: :xml,
                    show_translation: show_translation, show_children: show_children, kind: 'page'))
        assert_response :success

        # xml = get_xml_tree(@response.body)
        # puts xml
      end
    end

    num_terms = website.cms_terms.count
    post(url_for(controller: :cms_terms, action: :create, website_id: website.id, format: :xml),
         cms_term: { parent_id: term.id, language_id: spanish.id, kind: 'post', cms_identifier: 1, txt: 'mi pagina' })
    assert_response :success

    assert_equal num_terms + 1, website.cms_terms.count

    xml = get_xml_tree(@response.body)
    new_term_id = get_element_attribute(xml.root.elements['result'], 'id').to_i
    new_term = CmsTerm.find(new_term_id)

    assert_equal website, new_term.website

    # --- post another top level term
    post(url_for(controller: :cms_terms, action: :create, website_id: website.id, format: :xml),
         cms_term: { language_id: spanish.id, kind: 'post', cms_identifier: 2, txt: 'mi tambien' })
    assert_response :success

    xml = get_xml_tree(@response.body)
    assert_element_attribute('Term created', xml.root.elements['result'], 'message')
    new_term_id = get_element_attribute(xml.root.elements['result'], 'id').to_i
    new_term = CmsTerm.find(new_term_id)

    assert_equal 0, new_term.cms_term_translations.length

    # --- update the term
    put(url_for(controller: :cms_terms, action: :update, website_id: website.id, id: new_term.id, format: :xml),
        cms_term: { language_id: english.id })
    assert_response :success

    new_term.reload
    assert_equal english, new_term.language

    xml = get_xml_tree(@response.body)
    assert_element_attribute('Term updated', xml.root.elements['result'], 'message')

    # --- add translation to the new term
    post(url_for(controller: :cms_term_translations, action: :create, website_id: website.id, cms_term_id: new_term.id, format: :xml),
         cms_term_translation: { language_id: german.id, cms_identifier: 2, txt: 'yaya', status: 1 })
    assert_response :success

    xml = get_xml_tree(@response.body)
    assert_element_attribute('Translation created', xml.root.elements['result'], 'message')

    translation_id = get_element_attribute(xml.root.elements['result'], 'id').to_i
    cms_term_translation = CmsTermTranslation.find(translation_id)
    assert cms_term_translation
    assert_equal new_term, cms_term_translation.cms_term
    assert_equal german, cms_term_translation.language
    assert_equal 1, cms_term_translation.status
    assert_equal 'yaya', cms_term_translation.txt

    new_term.reload
    assert_equal 1, new_term.cms_term_translations.length

    # --- update the translation
    put(url_for(controller: :cms_term_translations, action: :update, website_id: website.id, cms_term_id: new_term.id, id: cms_term_translation.id, format: :xml),
        cms_term_translation: { language_id: english.id, txt: 'hello world', status: 2 })
    assert_response :success
    cms_term_translation.reload

    xml = get_xml_tree(@response.body)
    assert_element_attribute('Translation updated', xml.root.elements['result'], 'message')

    assert_equal english, cms_term_translation.language
    assert_equal 2, cms_term_translation.status
    assert_equal 'hello world', cms_term_translation.txt

    # try to create a duplicate - should return an error message
    n_terms = CmsTerm.count
    post(url_for(controller: :cms_terms, action: :create, website_id: website.id, format: :xml),
         cms_term: { language_id: english.id, kind: 'post', cms_identifier: 2, txt: 'I too' })
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert_element_attribute('Duplicate term already exists', xml.root.elements['result'], 'message')
    assert_equal n_terms, CmsTerm.count

    # CmsTerm.where('parent_id IS NULL').each do |c|
    #	puts "%d: website_id=%d, kind=%s, cms_identifier=%s, txt=%s"%[c.id,c.website_id, c.kind,c.cms_identifier,c.txt]
    # end

    # --- show the list of cms terms for the entire website
    get(url_for(controller: :cms_terms, action: :index, website_id: website.id, format: :xml,
                show_translation: 1, show_children: 1, cms_identifier: 2))
    assert_response :success

    cms_terms = assigns(:cms_terms)
    assert_equal 1, cms_terms.length

    # --- delete a term and its translations
    num_terms = website.cms_terms.count
    num_translations = CmsTermTranslation.count
    existing_translations_count = new_term.cms_term_translations.count
    assert_not_equal 0, existing_translations_count

    delete(url_for(controller: :cms_terms, action: :destroy, website_id: website.id, id: new_term.id, format: :xml))
    assert_response :success

    assert_equal num_terms - 1, website.cms_terms.count
    assert_equal num_translations - existing_translations_count, CmsTermTranslation.count

    logout(session)

  end

end
