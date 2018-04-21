function LoadCaptcha(client, key) {
  randcode = Math.floor(Math.random()*1000000);
  document.getElementById('CaptchaImage').src='http://www.icanlocalize.com/web_dialogs/gen_captcha?client='+client+'&key='+key+'&rand='+randcode;
  document.getElementById('rand').value=randcode;
}
