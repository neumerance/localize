 var loaded = false;

  function startLoading() {
    loaded = false;
    window.setTimeout('showLoadingImage()', 500);
  }

  function showLoadingImage() {
    var el = document.getElementById("loading_box");
    if (el && !loaded) {
        el.innerHTML = '<img src="/assets/ajax-loader.gif">';
        new Effect.Appear('loading_box');
    }
  }
  
   function stopLoading() {
    Element.hide('loading_box');
    loaded = true;
  }
  
  Ajax.Responders.register({
    onCreate : startLoading,
    onComplete : stopLoading
  });
  