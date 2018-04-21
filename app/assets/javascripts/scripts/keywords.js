function displayKeywordFields(fields_number){
  var html = "";
  jQuery("#keyword-fields").html("");
  for(var i=0; i< fields_number; i++){
    jQuery("#keyword-fields").append('<input type="text" name="keywords[]"/>');
  }
}

function remove_alt(elm){
  jQuery(elm).parent().remove();
  false
}

function addPossibleTranslation(elm){
  var keyword_id = jQuery(elm).parent().parent().attr("data-keyword-id");

  var to_add = "<div>";
  to_add += "Translation: <input name=\"keywords["+keyword_id+"]translations[]text\" type=\"text\"> ";
  to_add += "Montly hits: <input name=\"keywords["+keyword_id+"]translations[]hits\" type=\"text\"> ";
  to_add += "<a href=\"#\" onClick=\"remove_alt(this)\">(remove)</a>";
  to_add += "</div>";
  jQuery("#keyword_"+keyword_id).find(".translations").append(to_add);
  jQuery("#keyword_"+keyword_id).find(".translations").children().last().children().first().focus();
  jQuery("#keyword_"+keyword_id).find(".translations").children().last().children().first().select();

}

function addRelatedTerm(elm){
  var keyword_id = jQuery(elm).parent().parent().attr("data-keyword-id");

  var to_add = "<div>";
  to_add += "Related term: <input name=\"keywords["+keyword_id+"]terms[]text\" type=\"text\"> ";
  to_add += "Montly hits: <input name=\"keywords["+keyword_id+"]terms[]hits\" type=\"text\"> ";
  to_add += "<a href=\"#\" onClick=\"remove_alt(this)\">(remove)</a>";
  to_add += "</div>";
  jQuery("#keyword_"+keyword_id).find(".terms").append(to_add);
  jQuery("#keyword_"+keyword_id).find(".terms").children().last().children().first().focus();
  jQuery("#keyword_"+keyword_id).find(".terms").children().last().children().first().select();
}
