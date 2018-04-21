function select_local() {
 document.getElementById("source_entry").innerHTML='<p><b>Select file to check</b></p><ul><li>An HTML file</li><li>A ZIP file containing several HTML files (the ZIP file may include other files too, we will only scan the HTML files)</li></ul><p>File to upload: <input id="uploaded_data" name="uploaded_data" type="file" /></p>';
}
function select_remote() {
 document.getElementById("source_entry").innerHTML='<p><b>Enter address of website to check (URL)</b></p><p>Website address: <input id="url" name="url" type="text" size="60" /><br /><label><input id="recursive" type="checkbox" name="recursive" value="1" />Scan pages in other folders in this website</label></p><p>* Note: To scan inside a directory, make sure to include a trailing slash - <b>http://www.example.com/dirname/</b></p>';
}

function disable_submit() {
    document.getElementById("commit").disabled = true;
    document.getElementById("workingmsg").visibility = 'visible';
}