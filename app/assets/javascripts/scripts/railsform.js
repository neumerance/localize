var loaded_callback = null
var response_container = null
var elem = null

jQuery(document).ajaxSend(function(event, jqxhr, settings) {
    var el = document.createElement('a')
    el.href = settings.url
    elem = jQuery("[action='"+el.pathname+"'], [href='"+el.pathname + el.search +"']")
    if(elem.attr('data-loading')) {eval(elem.attr('data-loading'))}
    loaded_callback = elem.attr('data-loaded')
    response_container = elem.attr('data-update')
})


jQuery(document).ajaxComplete(function( event, xhr, settings ) {
    if(loaded_callback) { eval(loaded_callback) }
    if(response_container) { jQuery('#'+response_container).html(xhr.responseText) }
})
