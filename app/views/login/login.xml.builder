if @session_num
	xml.session_num(@session_num)
	if @user
		xml.user_id(@user.id)
	end
end
