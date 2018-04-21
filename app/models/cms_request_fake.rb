# This is to be used to create test projects for WebTA
class CmsRequestFake

  def initialize(translator = nil)
    @id = 0
    @title = 'Test translation project for WebTA'
    @permlink = 'https://icanlocalize.com'
    @cms_id = 0
    @word_count = 30
    @deadline = (Time.now + 5.days).to_i
    @started = (Time.now - 1.day).to_i
    @source_language = Language.find_by(name: 'English')
    @target_language = translator.to_languages.first if translator.present?
  end

  attr_accessor :id, :title, :permlink, :cms_id, :word_count, :deadline, :started, :source_language, :target_language

  def webta_format
    self.webta_attributes.to_json
  end

  def save_webta_progress(_xliff_id, _mrk_params)
    { code: 200, status: 'OK', message: 'Translation completed' }
  end

  def complete_webta(_user)
    { code: 200, status: 'OK', message: 'Translation completed' }
  end

  def preview
    'This is a test project, preview not available'
  end

  def find_mrks_count_by_cms_id
    {
      "0": { for_client: 0, for_translator: 0 }
    }
  end

  def create_mrk_issue(_a, _b)
    {
      data: {
        id: 0,
        attributes: {
          status: 'Test issue',
          message: 'test message',
          subject: 'Test subject'
        },
        links: {
          self: 'test_url'
        },
        messages: [
          {
            'id' => 0,
            'owner_id' => 0,
            'owner_type' => 'Test',
            'user_id' => 0,
            'body' => 'Test',
            'chgtime' => Time.now,
            'is_new' => 1,
            'user' => {
              name: 'Test',
              nickname: 'test',
              model: 'Translator'
            }
          }
        ],
        type: 'test'
      }
    }.to_json
  end

  def webta_attributes
    {
      id: self.id,
      title: self.title,
      is_test_project: true,
      permlink: self.permlink,
      cms_id: self.cms_id,
      word_count: self.word_count,
      deadline: self.deadline,
      started: self.started,
      source_language: self.source_language,
      target_language: self.target_language,
      website: {
        id: 0,
        name: 'Test website',
        description: 'This website is used for testing and training only',
        url: self.permlink
      },
      project: {
        id: 0,
        name: 'Test project'
      },
      revision: {
        id: 0,
        description: 'Revision used for testing',
        name: 'Test revision'
      },
      review_type: WEBTA_REVIEW_DISABLE,
      base_xliff: {
        id: 0,
        content_type: 'application/gzip',
        filename: 'test_filename.tar.gz',
        translated: false
      },
      content: build_mrk_pairs
    }
  end

  def build_mrk_pairs
    [
      { source_mrk: { id: 0,
                      mrk_status: 0,
                      mrk_id: 0,
                      content: 'Professional Translators of ICL' },
        target_mrk: { id: -1,
                      mrk_status: 0,
                      mrk_id: -1,
                      content: 'Professional Translators of ICL' } },
      { source_mrk: { id: 0,
                      mrk_status: 0,
                      mrk_id: 0,
                      content: 'A wide range of translator expertise' },
        target_mrk: { id: -2,
                      mrk_status: 0,
                      mrk_id: -2,
                      content: 'A wide range of translator expertise' } },
      { source_mrk: { id: -3,
                      mrk_status: 0,
                      mrk_id: -3,
                      content: 'All professional <g ctype="x-html-strong" id="gid_0">certified translators</g>' },
        target_mrk: { id: -4,
                      mrk_status: 0,
                      mrk_id: -5,
                      content: 'All professional certified <g ctype="x-html-strong" id="gid_0">translators</g>' } },
      { source_mrk: { id: -6,
                      mrk_status: 0,
                      mrk_id: -6,
                      content: "\n  <x ctype=\"lb\" id=\"gid_1\" xhtml:class=\"xliff-newline\"/>\n" },
        target_mrk: { id: -7,
                      mrk_status: 0,
                      mrk_id: -7,
                      content: "\n  <x ctype=\"lb\" id=\"gid_1\" xhtml:class=\"xliff-newline\"/>\n" } },
      { source_mrk: { id: -8,
                      mrk_status: 0,
                      mrk_id: -8,
                      content: 'All <g ctype="x-html-em" id="gid_2">translators</g> write in their <g ctype="x-html-strong" id="gid_3">native languages</g>' },
        target_mrk: { id: -9,
                      mrk_status: 0,
                      mrk_id: -9,
                      content: 'All <g ctype="x-html-em" id="gid_2">translators</g> write in their <g ctype="x-html-strong" id="gid_3">native languages</g>' } },
      { source_mrk: { id: -10,
                      mrk_status: 0,
                      mrk_id: -10,
                      content: "\n  <x ctype=\"lb\" id=\"gid_4\" xhtml:class=\"xliff-newline\"/>\n" },
        target_mrk: { id: -11,
                      mrk_status: 0,
                      mrk_id: -11,
                      content: "\n  <x ctype=\"lb\" id=\"gid_4\" xhtml:class=\"xliff-newline\"/>\n" } },
      { source_mrk: { id: -12,
                      mrk_status: 0,
                      mrk_id: -12,
                      content: 'You <g ctype="x-html-strong" id="gid_5">choose the <g ctype="x-html-span" id="gid_6" xhtml:style="text-decoration: underline;"><g ctype="x-html-em" id="gid_7">translators</g></g></g> for your projects' },
        target_mrk: { id: -13,
                      mrk_status: 0,
                      mrk_id: -13,
                      content: 'You <g ctype="x-html-strong" id="gid_5">choose the <g ctype="x-html-span" id="gid_6" xhtml:style="text-decoration: underline;"><g ctype="x-html-em" id="gid_7">translators</g></g></g> for your projects' } },
      { source_mrk: { id: -14,
                      mrk_status: 0,
                      mrk_id: -14,
                      content: "\n  <g ctype=\"x-html-caption\" id=\"gid_8\" xhtml:id=\"attachment_354\" xhtml:align=\"alignnone\" xhtml:width=\"300\"><x ctype=\"image\" id=\"gid_9\" xhtml:class=\"size-medium wp-image-354\" xhtml:src=\"http://wp-site.otgs-yt.tk/wp-content/uploads/2017/08/Language-Translators-300x72.png\" xhtml:alt=\"Top Translators\" xhtml:width=\"300\" xhtml:height=\"72\"/> Top Translators</g>\n" },
        target_mrk: { id: -15,
                      mrk_status: 0,
                      mrk_id: -15,
                      content: "\n  <g ctype=\"x-html-caption\" id=\"gid_8\" xhtml:id=\"attachment_354\" xhtml:align=\"alignnone\" xhtml:width=\"300\"><x ctype=\"image\" id=\"gid_9\" xhtml:class=\"size-medium wp-image-354\" xhtml:src=\"http://wp-site.otgs-yt.tk/wp-content/uploads/2017/08/Language-Translators-300x72.png\" xhtml:alt=\"Top Translators\" xhtml:width=\"300\" xhtml:height=\"72\"/> Top Translators</g>\n" } },
      { source_mrk: { id: -16,
                      mrk_status: 0,
                      mrk_id: -16,
                      content: "\n  <x ctype=\"lb\" id=\"gid_10\" xhtml:class=\"xliff-newline\"/>\n" },
        target_mrk: { id: -17,
                      mrk_status: 0,
                      mrk_id: -17,
                      content: "\n  <x ctype=\"lb\" id=\"gid_10\" xhtml:class=\"xliff-newline\"/>\n" } },
      { source_mrk: { id: -18,
                      mrk_status: 0,
                      mrk_id: -18,
                      content: "\n  <x ctype=\"lb\" id=\"gid_11\" xhtml:class=\"xliff-newline\"/>\n" },
        target_mrk: { id: -19,
                      mrk_status: 0,
                      mrk_id: -19,
                      content: "\n  <x ctype=\"lb\" id=\"gid_11\" xhtml:class=\"xliff-newline\"/>\n" } }
    ]
  end

  def auto_save_untranslatable_mrks; end

end
