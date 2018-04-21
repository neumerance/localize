// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or any plugin's vendor/assets/javascripts directory can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// compiled file.
//
// Read Sprockets README (https://github.com/rails/sprockets#sprockets-directives) for details
// about supported directives.
//
//= require jquery
//= require jquery_ujs
//= require dataTables/jquery.dataTables
//= require plugins/bootstrap-modalmanager.min
//= require plugins/bootstrap-modal.min
//= require jquery-ui
//= require jquery.remotipart
//= require plugins/modalbox
//= require scripts/checkIE
//= require plugins/jquery.form.min
//= require scripts/ajaxFormUploader
//= require plugins/jquery.fileDownload
//= require highcharts
//= require plugins/messenger
//= require plugins/messenger-theme-future
//= require data_table
//= require plugins/moment
//= require plugins/moment-with-locales.min
//= require plugins/moment-duration-format
//= require plugins/knockout-3.4.2
//= require plugins/daterangepicker.min
//= require plugins/jquery.webui-popover.min
//= require plugins/jquery.rateyo.min

Messenger.options = {
    extraClasses: 'messenger-fixed messenger-on-top messenger-on-right',
    theme: 'air'
}
Messenger.themes.air = { Message: Messenger.themes.future['Message'] };

var icl_notification = function(text){
  try{
    Messenger().post({message: text});
  }catch(e){
    alert(text)
  }
}