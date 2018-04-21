function hide_login() {
 document.getElementById("login").style.visibility="hidden";
 document.getElementById("login_preview").style.visibility="visible";
}
function show_login() {
 document.getElementById("login").style.visibility="visible";
 document.getElementById("login_preview").style.visibility="hidden";
}

function load_in_window(url) {
var load = window.open(url,'','scrollbars=yes,height=600,width=1000,resizable=yes,toolbar=no,location=no,status=no,menubar=no');
}
