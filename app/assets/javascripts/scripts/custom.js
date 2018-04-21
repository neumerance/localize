// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults

function hide_reminders() {
    jQuery('#reminders').hide()
    jQuery('#reminders_preview').show()
}
function show_reminders() {
    jQuery('#reminders').show()
    jQuery('#reminders_preview').hide()
}

counter = 1

function add_another_file(max_size)
{
    ++counter;
    var p_elem = jQuery('<p>')
    var inp_elem = jQuery('<input type="file">')
    var name = "file"+counter+"[uploaded_data]"
    inp_elem.attr('id', "file"+counter+"_uploaded_data")
    inp_elem.attr('name', name)
    inp_elem.attr('onchange', 'validate_file_size(\''+name+'\', '+max_size+')')
    p_elem.append(inp_elem)
    var form = jQuery('#documents_to_upload')
    form.append(p_elem)
}

function printpage()
{
    document.getElementById("printcontrol").innerHTML='';
    window.print();
}

function show_div(divid, shown) {
    document.getElementById(divid).style.display = shown;
}

function show_div_or_radio(divid, shown, element_id) {
    if (shown == 'none') {
        other_radio = document.getElementById(element_id);
        if (other_radio.checked) {
            to_show = 'block'; }
        else {
            to_show = 'none'; }
    }
    else {
        to_show = shown; }
    document.getElementById(divid).style.display = to_show;
}

function highlight_resource_format() {
    selector = document.getElementById(resource_format_id);
    val = selector.value;
    format_id='format'+to_i(val);
    element = document.getElementById(format_id);
    element.style.weight = 'bold'
}

function toggleCheckBoxes(formId) {
    var form = jQuery('#' + formId);
    jQuery.each(form.find('[type="checkbox"]'), function (idx, elem) {
        var elem = jQuery(elem)
        elem.is(':checked') ? elem.prop('checked', false) : elem.prop('checked', true)
    })
}

function set_all_checkboxes(checkbox_name, value, submits_name)
{
    var elems = jQuery('[name="'+checkbox_name+'"]')
    jQuery.each(elems, function(idx, elem){
        var elem = jQuery(elem)
        if(elem.attr('name') == 'checkbox'){
            elem.prop('checked', true)
        }
    })

    if(submits_name) { set_submits_disable(checkbox_name, submits_name) }
}

function set_submits_disable(checkbox_name, submits_name) {
    var elems = jQuery('[name="'+checkbox_name+'"]')
    var count = 0
    jQuery(elems, function(idx, elem){
        var elem = jQuery(elem)
        if(elem.is(':checked')){ count++ }
    })
    if(count > 0) { jQuery('[name="'+submits_name+'"]').prop('disabled', false) }
}

function send_translations(checkbox_name,text_resource_id) {
    var form = document.createElement("form")
    form.setAttribute("method", "post")
    form.setAttribute("action", "/text_resources/"+text_resource_id+"/resource_chats/start_translations")

    elems = document.getElementsByName(checkbox_name)
    for(var i=0; i < elems.length; i++)
    {
        if(elems[i].type == "checkbox")
        {
            if(elems[i].checked)
            {
                var field = document.createElement("input")
                field.setAttribute("type", "hidden")
                field.setAttribute("name", "selected_chats[]")
                field.setAttribute("value", elems[i].value)
                form.appendChild(field);
            }
        }
    }

    document.body.appendChild(form);
    return form.submit();
}

function confirm_send_translations(message, checkbox_name,text_resource_id){
    var answer = confirm(message)
    if(answer){ send_translations(checkbox_name,text_resource_id) }
}

function toggle_hide(img_id, elm_id)
{
    var elm = jQuery('#'+elm_id)
    var img = jQuery('#'+img_id)
    if(elm.is(':visible'))
    {
        img.attr('src', '/assets/more.png')
        elm.slideUp(300)
    }
    else
    {
        img.attr('src', '/assets/less.png')
        elm.slideDown(300)
    }
}

function update_tool(user_id,tool,tool_id){
    jQuery.ajax({
        url: '/users/'+user_id+'/update_tool',
        type: 'POST',
        data: {tool: tool, tool_id: tool_id, value: jQuery('#'+tool+tool_id+':checked').val()},
        success: function(res){
        }
    })
}

function toggle_project_list(){
    var divs_to_toggle = [jQuery('#all_projects'), jQuery('#projects_list')]
    jQuery.each(divs_to_toggle, function(k, v) {
        v.toggle()
    })
}

function toggleAdminNotifications(id){
    jQuery.ajax({
        url: '/users/'+id+'/toggle_admin_notifications',
        method: 'POST'
    })
}

// Used in software projects when language checkbox is clicked
function fix_total_amount(elm){
    return update_totals();
}


function calculate_tax(val, tax_rate){
    var total = (val * tax_rate) / 100;
    // PayPal takes invoice.gross_amount and invoice.tax_rate as parameters,
    // calculates the tax amount (rounding with floor and not ceil) and adds it
    // to the payment. Se we must use floor here too, or else our tax calculation
    // will be 1 cent greater than PayPal's calculation.
    return Math.floor(total * 100) / 100;
}

// Used in deposit to account
function update_totals(){
    var $table = jQuery('#total_box');

    var amounts = $table.find('.item .amount').map(function(){
        var amount = 0;
        if ( jQuery(this).find('input').length ) {
            var $el = jQuery(this).find('input');
            var replace_method = function(v){ $el.val(v) };
            var orig_amount = jQuery(this).find('input').val();
        }else{
            var $el = jQuery(this);
            var replace_method = function(v){$el. text(v) };
            var orig_amount = jQuery(this).text();
        };

        var $checkbox = jQuery(this).parents('tr').find('input[type=checkbox]');
        if ($checkbox.length) {
            if (!$checkbox.is(':checked')) {
                $el.parents('tr').addClass('grayed-out');
                return 0;
            }else{
                $el.parents('tr').removeClass('grayed-out');
            };
        };

        amount = parseFloat(orig_amount.replace(/^0+(?!\.)/, '').replace(/[^0-9\.]/g, '').match(/^\d+\.\d{0,2}|\d+/));

        if (isNaN(amount)) {amount = 0;};
        var _inProgress = orig_amount.slice(-1) == '.' || orig_amount.slice(-2) == '.0' || orig_amount == '';
        if (!_inProgress && amount.toString() != orig_amount) {replace_method(amount);};
        return amount;
    }).get();

    // Total translation jobs cost row (without tax)
    // NOTE: prototypeJS overwrites js reduce native method which was the right way to sum all elements
    var total = 0;
    jQuery.each(amounts, function(idx, val){
        total += val
    });
    var subtotal = total;
    var tax = 0;

    // ICL account balance row
    // Subtract the balance from the client's ICL account from the total amount of the translation jobs
    if ($table.find('.current_in_account').length) {
        total -= parseFloat($table.find('.current_in_account .amount').text()).toFixed(2);
        // If the client's balance is greater than the amount of the translation
        // jobs, don't display a negative "total".
        if (total < 0) total = 0;
    }

    // Subtotal row (total cost - client ICL account balance)
    if (subtotal > 0) {
        var subTotalRow = $table.find('.subtotal');
        if (subTotalRow.length && subTotalRow.hasClass('software-translation')){
            subTotalRow.find('.amount').text(subtotal.toFixed(2).toString());
        }else{
            subTotalRow.find('.amount').text(total.toFixed(2).toString());
        }
    } else {
        // There is nothing to pay for, so there are no taxes.
        // Hide everything related to taxes.
        jQuery('#vat_request').hide();
        jQuery('tr.subtotal, tr.tax_details').hide();
    }

    // Tax row
    var tax_row = $table.find('.tax_details:visible');
    if (tax_row.length > 0) {
        var tax_rate    = parseFloat(jQuery('.tax_rate').text());
        tax = parseFloat(calculate_tax(total, tax_rate));
        if (tax < 0 || isNaN(tax)) { tax = 0 };
        $table.find('.tax_details .amount').text( tax.toFixed(2).toString() );

        total += ceilMoney(tax);
    }

    // Total row
    if (total > 0) {
        $table.find('#total_cost').text(total.toFixed(2).toString());
    } else {
        $table.find('#total_cost').text('0.00 (your ICL account balance is enough to cover these translation jobs)');
        // Hack to remove the 'USD' which is prepended to the above message in the
        // view. More than one view and their helpers use this and we don't have
        // time to refactor them now.
        jQuery('th:last-of-type').text(function(index, text) {
            return text.replace('USD', '');
        });
    }

    // Disable the "Pay with PayPal" button but not the "Pay with your ICL
    // account balance" button in the new WPML flow.
    var submitButton = $table.parents('form').find('input[type="submit"]:not(#pay-with-icl-balance)');

    if (total <= 0) {
        submitButton.attr('disabled','disabled');
    }else{
        submitButton.removeAttr('disabled');
    }
}

function validate_file_size(name, max_size){
    var max_size = parseInt(max_size)
    var field = jQuery('input[name="'+name+'"]')
    var size = parseInt(field[0].files[0].size) / 1024
    if (size > max_size) {
        alert('File is too large, please use a file less than or equal to ' + parseInt(max_size / 1000) + ' mb')
        field.val('')
    }
}

function validate_money_field(elem){
    var maxPlaces = 2,
        integer = elem.value.split('.')[0],
        mantissa = elem.value.split('.')[1]
    if (typeof mantissa === 'undefined') {
        mantissa = ''
    }
    if (mantissa.length > maxPlaces) {
        elem.value = integer + '.' + mantissa.substring(0, 2);
    }
    if (elem.value.length > elem.maxLength) elem.value = elem.value.slice(0, elem.maxLength)
}

function toggleTickboxes(){
    var elems = jQuery('[name="selected_chats[]"]:checked')
    var btn = jQuery('[name="begin_translations"]')
    if(elems.length > 0) {
        btn.prop('disabled', false)
    } else {
        btn.prop('disabled', true)
    }
}

function toggleAllTickbox(){
    var a = jQuery('.tickToggler')
    var status = a.attr('data-status')
    if(status == '0') {
        jQuery('[name="selected_chats[]"]').prop('checked', true)
        a.attr('data-status', 1)
        a.text('Un-check all languages')
    } else {
        jQuery('[name="selected_chats[]"]').prop('checked', false)
        a.attr('data-status', 0)
        a.text('Select all languages')
    }
    toggleTickboxes()
}

function accordion(elem) {
  jQuery(elem).click(function(e) {
    e.preventDefault();

    var $this = jQuery(this);

    if ($this.next().hasClass('show')) {
      $this.next().removeClass('show');
      $this.next().slideUp(350);
      $this.addClass('closed').removeClass('open')
    } else {
      $this.next().toggleClass('show');
      $this.next().slideToggle(350);
      $this.removeClass('closed').addClass('open')
    }
  });
}

function toggleExplanationBox(radio, textarea) {
    jQuery('[name="'+radio+'"]').on('click', function(){
        if(jQuery(this).val() == 'more_explanation') {
            jQuery('#'+textarea).slideDown(300)
        } else {
            jQuery('#'+textarea).slideUp(300)
        }
    })
}

function setUpLoginForm(){
    jQuery('#new-account').css('display', 'none')
    jQuery('#reuse_translators_button').prop('disabled', false)
    jQuery('#existing-account').css('display', 'block')
}

function setUpSignUpForm(){
    jQuery('#new-account').css('display', 'block')
    jQuery('#reuse_translators_button').prop('disabled', true)
    jQuery('#existing-account').css('display', 'none')
}

jQuery(document).ready(function(){
    if(jQuery('[name="selected_chats[]"]').length == 0) {
        jQuery('.tickToggler').hide()
        jQuery('[name="begin_translations"]').hide()
    }
})

function downloadFile(form) {
    var form = jQuery(form)
    var preloader = form.find('button.preloader')
    var action = form.attr('action') + '?' + form.serialize()
    preloader.find('.spinner').show()
    preloader.find('span').text('please wait ...')
    preloader.attr('disabled', true)

    var reenableCallback = function() {
        preloader.find('.spinner').hide()
        preloader.find('span').text('Generate')
        preloader.attr('disabled', false)
    }

    jQuery.fileDownload(action, {
        successCallback: function() {
            reenableCallback()
        },
        failCallback: function() {
            reenableCallback()
        }
    })

    return false
}

function toggleButton(targets, elem) {
    jQuery.each(jQuery(targets), function(idx, el) {
        var target = jQuery(el)
        if(jQuery(elem).is(':checked')) {
            target.attr('disabled', true)
            if(target.attr('href')) {
                target.attr('data-href', target.attr('href'))
                target.removeAttr('href')
            }
        } else {
            target.attr('disabled', false)
            if(target.attr('data-href')) {
                target.attr('href', target.attr('data-href'))
                target.removeAttr('data-href')
            }
        }
    })
}

function formatDuration(secs) {
    return moment.duration(secs*1000).format("h:mm:ss")
}

function countdownTimer(time, timeout, placeholder, onFinish) {
    var now = moment()
    var then = moment.utc(time, 'YYYY-MM-DD h:mm:ss').add(timeout, 'seconds')
    var remaining = moment.duration(then.diff(now)).asSeconds()
    setInterval(function () {
        --remaining;
        if (remaining > 0) {
            jQuery(placeholder).text(formatDuration(remaining))
        } else {
            onFinish()
        }
    }, 1000)
}

var formatter = new Intl.NumberFormat('en-US', {
  style: 'currency',
  currency: 'USD',
  minimumFractionDigits: 2
});

function makeID() {
  var text = ""
  var possible = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
  for( var i=0; i < 5; i++ )
    text += possible.charAt(Math.floor(Math.random() * possible.length));
  return text
}
