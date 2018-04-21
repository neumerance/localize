(function(){

	// Table checkboxes
	jQuery('.mc-checkall').click(function () {
		jQuery(this).parents('fieldset:eq(0)').find(':checkbox').attr('checked', this.checked);
		jQuery(this).parents('fieldset:eq(0)').find(':checkbox').toggleClass('mc-selected-tr');

		// Marks the current row (yellow background)
		if (this.checked) {
			jQuery('.mc-toggle-checkbox').closest('tr').addClass('mc-selected-tr');
		} else {
			jQuery('.mc-toggle-checkbox').closest('tr').removeClass('mc-selected-tr');
		}

		buttonsToggle(this);
	});

	jQuery('.mc-toggle-checkbox').click(function() {
		jQuery(this).closest('tr').toggleClass('mc-selected-tr');
		buttonsToggle(this);
	});

	// Table enable/disable dropdown buttons
	function buttonsToggle(el) {
		if(el.checked) {
			jQuery('#mc-btnChangeDeadline, #mc-btnChangeRate').removeClass('mc-disabled');
		}
		if( ! jQuery('.mc-toggle-checkbox').closest('tr').hasClass('mc-selected-tr') ) {
			jQuery('#mc-btnChangeDeadline, #mc-btnChangeRate').addClass('mc-disabled');

			// Hides mc-dd-box when all .mc-toggle-checkbox are unchecked
			jQuery('.mc-dd-box').hide();
			jQuery('#mc-btnChangeDeadline, #mc-btnChangeRate').removeClass('mc-activated');

			// Removes the checked attribute for .mc-checkall when all .mc-toggle-checkbox are unchecked
			if ( jQuery('.mc-checkall').attr('checked', this.checked) ) {
				jQuery('.mc-checkall').removeAttr('checked');
			}
		}
	}

	jQuery('#mc-btnChangeDeadline, #mc-btnChangeRate').click(function () {
		buttonsBoxOpen(jQuery(this));
	});

	function buttonsBoxOpen(el) {
		if( ! el.hasClass('mc-disabled') ) {
			if( el.hasClass('mc-activated') ) {

				el.removeClass('mc-activated');
				el.parent('.mc-dd-box-wrap').find('.mc-dd-box').hide();


			} else {
				el.addClass('mc-activated');
				el.parent('.mc-dd-box-wrap').find('.mc-dd-box').show();
			}

			// Close the mc-dd-box with mc-close button
			el.parent('.mc-dd-box-wrap').find('.mc-dd-box').click(function() {
				el.removeClass('mc-activated');
				el.parent('.mc-dd-box-wrap').find('.mc-dd-box').hide();
			});

		} else {
			// Nothing happens if a row isn't selected
		}
	}
})(jQuery);

function change_deadline(pair_id, ev){
  Effect.toggle('boxChangeDeadline', 'appear', {duration: 0.1});
  var x_offset;
  if (ev.pageX -400 > 0)
    x_offset = ev.pageX - 400
  else
    x_offset = ev.pageX + 10
      Element.setStyle('boxChangeDeadline', { left: x_offset + 'px', top: ev.pageY - 50 + 'px'});

  url = '/translation_analytics_language_pairs/edit_deadlines' + '?' + reuse_get_parameters() + "&language_pair_id=" + pair_id;

  $$("input[language_id]:checked").each(function(i){
    url += "&language_pairs[]=" + i.readAttribute('language_id');
  })

  new Ajax.Updater('boxChangeDeadline', url);
}
