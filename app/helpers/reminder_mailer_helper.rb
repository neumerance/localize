module ReminderMailerHelper
  def action_button(text, url)
    raw '<div><!--[if mso]><v:roundrect xmlns:v="urn:schemas-microsoft-com:vml" xmlns:w="urn:schemas-microsoft-com:office:word" href="' + url + '" style="height:40px;v-text-anchor:middle;width:200px;" arcsize="10%" strokecolor="#D26918" fillcolor="#ed9c28"><w:anchorlock/><center style="color:#ffffff;font-family:\'Lucida Grande\',Verdana,Arial,sans-serif;font-size:18px;font-weight:normal;">' + text + '</center></v:roundrect><![endif]--><a href="' + url + '" style="background:#ed9c28 !important;border:1px solid #D26918;border-radius:4px;color:#fff!important;display:inline-block;font-family:\'Lucida Grande\',Verdana,Arial, sans-serif;font-size:18px;font-weight:normal;line-height:40px;text-align:center;text-decoration:none;width:200px;-webkit-text-size-adjust:none;mso-hide:all;">' + text + '</a></div>'
  end

  def centered_action_button(text, url)
    raw '<p style="text-align:center"><!--[if mso]><v:roundrect xmlns:v="urn:schemas-microsoft-com:vml" xmlns:w="urn:schemas-microsoft-com:office:word" href="' + url + '" style="height:40px;v-text-anchor:middle;width:500px;" arcsize="10%" strokecolor="#D26918" fillcolor="#ed9c28"><w:anchorlock/><center style="color:#ffffff;font-family:\'Lucida Grande\',Verdana,Arial,sans-serif;font-size:18px;font-weight:normal;">' + text + 'text</center></v:roundrect><![endif]--><a href="' + url + '" style="background:#ed9c28 !important;border:1px solid #D26918;border-radius:4px;color:#fff!important;display:inline-block;font-family:\'Lucida Grande\',Verdana,Arial, sans-serif;font-size:18px;font-weight:normal;line-height:40px;text-align:center;text-decoration:none;width:500px;-webkit-text-size-adjust:none;mso-hide:all;">' + text + '</a></p>'
  end

  def warning_button(text, url)
    raw '<div><!--[if mso]><v:roundrect xmlns:v="urn:schemas-microsoft-com:vml" xmlns:w="urn:schemas-microsoft-com:office:word" href="' + url + '" style="height:40px;v-text-anchor:middle;width:200px;" arcsize="10%" strokecolor="#a31414" fillcolor="#da1f2a"><w:anchorlock/><center style="color:#ffffff;font-family:sans-serif;font-size:13px;font-weight:bold;">' + text + '</center></v:roundrect><![endif]--><a href="' + url + '" style="background:#da1f2a !important;border:1px solid #a31414;border-radius:4px;color:#fff;display:inline-block;font-family:sans-serif;font-size:18px;font-weight:normal;line-height:40px;text-align:center;text-decoration:none;width:200px;-webkit-text-size-adjust:none;mso-hide:all;">' + text + '</a></div>'
  end

  def notification_button(text, url)
    raw '<div><!--[if mso]><v:roundrect xmlns:v="urn:schemas-microsoft-com:vml" xmlns:w="urn:schemas-microsoft-com:office:word" href="' + url + '" style="height:40px;v-text-anchor:middle;width:200px;" arcsize="10%" strokecolor="#269abc" fillcolor="#39b3d7"><w:anchorlock/><center style="color:#ffffff;font-family:sans-serif;font-size:18px;font-weight:normal;">' + text + '</center></v:roundrect><![endif]--><a href="' + url + '" style="background:#39b3d7 !important;border:1px solid #269abc;border-radius:4px;color:#ffffff;display:inline-block;font-family:sans-serif;font-size:18px;font-weight:normal;line-height:40px;text-align:center;text-decoration:none;width:200px;-webkit-text-size-adjust:none;mso-hide:all;">' + text + '</a></div>'
  end

end
