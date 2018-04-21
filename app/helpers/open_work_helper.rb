module OpenWorkHelper
  def language_list(revision)
    content_tag(:ul, class: 'nobullet', style: 'margin-top:0; padding-top:0') do
      revision.revision_languages.where('NOT EXISTS(SELECT * FROM bids b WHERE (b.revision_language_id = revision_languages.id) AND (b.won = 1))').each do |rl|
        concat content_tag(:li) {
          concat content_tag(:span, revision.language.name); concat ' to '.html_safe; concat content_tag(:span, rl.language.name)
        }
      end
    end
  end
end
