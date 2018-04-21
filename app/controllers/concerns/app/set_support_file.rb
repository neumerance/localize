module App
  module SetSupportFile
    def set_support_file(id)
      # get the support_file and check that it's part of the message
      begin
        @support_file = SupportFile.find(id)
        if @support_file.owner_id != @project.id
          set_err('Support file is not part of this project')
          return false
        end
      rescue
        set_err('Support file not found')
        return false
      end
      true
    end
  end
end
