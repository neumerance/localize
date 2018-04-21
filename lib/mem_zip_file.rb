require 'zip/zipfilesystem'

class MemZipFile < Zip::ZipFile

  def initialize(stream)
    Zip::ZipCentralDirectory.initialize
    @name = 'memstream'
    @comment = ''
    read_from_stream(stream)
    @create = create
    @storedEntries = @entrySet.dup

    @restore_ownership = false
    @restore_permissions = false
    @restore_times = true
  end

end
