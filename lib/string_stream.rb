class StringStream

  def initialize(str)
    @str = str
    @pos = 0
  end

  def read(n = nil)
    num = @str.length - @pos
    if n
      num = n if n + @pos <= @str.length
    end

    res = @str[@pos, (@pos + num)]
    @pos += num
    res
  end

  def seek(num, mode)
    if mode == IO::SEEK_SET
      @pos = num
    elsif mode == IO::SEEK_END
      @pos = @str.length + num
    elsif mode == IO::SEEK_CUR
      @pos += num
    else
      raise 1, "Unknown seek command #{mode}"
    end
  end

  def close; end

end
