module ShortcodesHelper
  def type_description
    "<b>Atomic:</b> A shortcode that doesn't require a closing shortcode. For example:. <br>&nbsp;&nbsp;&nbsp;<i class='comment'><span>[wpv-view]</span></i><br/><br/>" \
      "<b>Open and close:</b> A shortcode that requires a closing shortcode, but the text between the two will be translated. For example: <br>&nbsp;&nbsp;&nbsp;<i class='comment'><span>[message]</span>This is important<span>[/message]</span></i><br/><br/>" \
      "<b>Open, exclude and close:</b> A shortcode that requires a closing shortcode and the text between the two will also be excluded from translation. For example: <br>&nbsp;&nbsp;&nbsp;<i class='comment'><span>[message]</span>This is important<span>[/message]</span></i><br/>"
  end

  def table_headers
    if @user.has_admin_privileges?
      ['Shortcode', "Type #{tooltip(type_description, true)}", 'Created by', 'Comment', 'Actions']
    else
      ['Shortcode', "Type #{tooltip(type_description, true)}", 'Comment', 'Actions']
    end
  end

  def nice_content_type(content_type)
    Shortcode::CONTENT_TYPE_NAMES[
      Shortcode::CONTENT_TYPE_OPTIONS.index(content_type)
    ]
  end

  def shortcodes_link
    @website ? website_shortcodes_path(@website) : shortcodes_path
  end

  # alias_method :orig_toggle_enabled_shortcode_path, :toggle_enabled_shortcode_path
  def toggle_enabled_shortcode_link(*args)
    if @website
      toggle_enabled_website_shortcode_path(@website, *args)
    else
      toggle_enabled_shortcode_path(*args)
    end
  end

  # alias_method :orig_edit_shortcode_path, :edit_shortcode_path
  def edit_shortcode_link(*args)
    if @website
      edit_website_shortcode_path(@website, *args)
    else
      edit_shortcode_path(*args)
    end
  end

  # alias_method :orig_destroy_shortcodes_path, :destroy_shortcodes_path
  def destroy_shortcode_link(shortcode)
    if @website
      [@website, shortcode]
    else
      shortcode
    end
  end

end
