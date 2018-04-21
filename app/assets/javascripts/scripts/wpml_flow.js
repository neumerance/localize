var ceilMoney = function(amount) {
    var cents = amount * 100;
    return Math.ceil(cents) / 100;
};

var floorMoney = function(amount) {
    var cents = amount * 100;
    return Math.floor(cents) / 100;
};

jQuery(function() {
    // The code below is only executed on the index view of TranslationJobsController
    if (jQuery('.translation_jobs-controller.index-action').length === 0) return;

    jQuery('#interview_translators').click(function() {
        jQuery('.hidden').removeClass('hidden');
    });
});

