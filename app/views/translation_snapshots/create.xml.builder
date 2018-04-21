if @error
	xml.response(:status => "error", :message => @error)
else
	xml.response(:status => "success")
end
