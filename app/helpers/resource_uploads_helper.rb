module ResourceUploadsHelper
  include TextResourcesHelper

  def resource_strings_table(resource_strings)
    content_tag(:div) do
      concat content_tag(:table, class: 'stats', cellspacing: 0, cellpadding: 3) {
        concat content_tag(:tr, class: 'headerrow') {
          %w(Include Label Text Comment Status).each do |th|
            concat content_tag(:th, th)
          end
        }
        resource_strings.each do |resource_string|
          concat content_tag(:tr) {
            bg_color = ResourceUploadsController::NEW_STRING_COLOR_CODE[resource_string[:status]]
            concat content_tag(:td, style: "background: #{bg_color}") {
              unless [ResourceUploadsController::NEW_STRING_EXISTS, ResourceUploadsController::NEW_STRING_BEING_TRANSLATED].include?(resource_string[:status])
                check_box_tag("string_token[#{Digest::MD5.hexdigest(resource_string[:token])}]", 1, true)
              end
            }
            concat content_tag(:td, pre_format(resource_string[:token]), style: "background: #{bg_color}")
            concat content_tag(:td, pre_format(resource_string[:text]), style: "background: #{bg_color}")
            concat content_tag(:td, pre_format(resource_string[:comments]), style: "background: #{bg_color}", class: 'comment')
            concat content_tag(:td, ResourceUploadsController::NEW_STRING_TEXT[resource_string[:status]], style: "background: #{bg_color}")
          }
        end
      }
    end
  end

  def modified_strings_table(modified_strings)
    res = [infotab_header(['Label', 'Existing text', 'New text'])]
    modified_strings.each do |modified_string|
      res << "<tr><td>#{pre_format(modified_string[0])}</td><td>#{pre_format(modified_string[1])}</td><td>#{pre_format(modified_string[2])}</td></tr>"
    end
    res << ['</table>']
    res.join
  end
end
