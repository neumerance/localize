require 'fileutils'

class VersionCreator
  def initialize
    @sources = []
    @fname = nil
  end

  def add_source(fname, lang)
    @sources << [fname, lang]
  end

  def generate(fname)
    # very temporary generate code - takes just the last source and copies to the target
    src = @sources[-1][0]
    if File.exist?(fname)
      return false
    else
      FileUtils.copy(src, fname)
      return true
    end
    @fname = fname
  end

  def get_size
    File.size(@fname)
  end
end
