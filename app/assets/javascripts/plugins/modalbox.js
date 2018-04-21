var Modalbox = {
    getModal: function(){
        return jQuery('#appModal')
    },
    setContent: function(content){
        this.getModal().find('.modal-body').html(content)
    },
    setTitle: function(title){
        this.getModal().find('.modal-header h4').text(title)
    },
    removeContent: function(){
        this.getModal().find('.modal-body').html('')
    },
    show: function(content, options){
        if(options.width) {
            this.getModal().attr('data-width', options.width)
        }
        if(options.title) { this.setTitle(options.title) }
        this.setContent(content)
        this.getModal().modal('show')
    },
    hide: function(){
        this.removeContent()
        this.getModal().modal('hide')
    }
}
