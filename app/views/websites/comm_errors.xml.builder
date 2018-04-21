xml.comm_errors do
	@comm_errors.each do |comm_error|
		xml.comm_error(comm_error.error_description, :id=>comm_error.id, :status=>comm_error.status, :error_code=>comm_error.error_code, :created_at=>comm_error.created_at.to_i, :updated_at=>comm_error.updated_at.to_i)
	end
end