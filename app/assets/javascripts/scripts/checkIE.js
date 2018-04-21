function isIE(){
    if (navigator.userAgent.match(/msie/i) || navigator.userAgent.match(/trident/i) ){
        return true
    }
    return false
}