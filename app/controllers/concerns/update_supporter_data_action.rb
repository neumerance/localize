module UpdateSupporterDataAction
  def update_supporter_data
    obj = controller_name.classify.constantize.find(params[:id])
    logger.debug obj.inspect
    logger.debug params.inspect
    obj.update_attributes(params[params[:controller].singularize])
    flash[:notice] = _('Updated!')
    redirect_to action: :show
  end
end
