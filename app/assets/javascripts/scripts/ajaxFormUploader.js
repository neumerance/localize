// introducing this to fix failing upload in IE
// remember to init the multipart ajax form
// just add <script>initMutiPartForm('#id_of_your_form')</script> below the form.
// also remove data-remote attr

function initMutiPartForm(form) {
    jQuery(document).ready(function(){
        jQuery(form).submit(function() {
            jQuery(this).ajaxSubmit({});
            return false;
        });
    })
}