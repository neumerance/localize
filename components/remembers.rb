module Remembers
  def cached(key)
    logger.info "CACHE (#{self.class}) -------------------- looking for #{key} "
    unless @self_cache
      logger.info "CACHE (#{self.class}) -------------------- creating cache "
      @self_cache = {}
    end

    if @self_cache.key?(key)
      logger.info "CACHE (#{self.class}) -------------------- getting #{key} "
      return @self_cache[key]
    else
      res = yield
      @self_cache[key] = res
      logger.info "CACHE (#{self.class}) -------------------- storing #{key} "
      return res
    end
  end

  def clear_cache
    @self_cache = nil
  end
end
