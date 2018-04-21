module Lockable

  def get_lock(locker)

    obj_name = "#{self.class}[#{id}]"

    for attempt in 0..50
      if !lock
        begin
          self.lock = Lock.new(locked_by: locker,
                               lock_time: Time.now)

          # try to save the lock, if it goes OK, return OK
          # if the lock already exists, the database will cause an error
          # logger.info "------ LOCK OK: #{self.class}.#{self.id} locked by #{locker} on #{self.lock.lock_time}"
          if lock.save
            logger.info " ---------- LOCK #{obj_name}: got lock on attempt #{attempt}"
            return true
          end
        rescue
          logger.info " ---------- LOCK #{obj_name}: couldn't save lock. attempt: #{attempt}"
        end
      else
        logger.info " ---------- LOCK #{obj_name}: lock exists. attempt: #{attempt}"
      end
      sleep 0.1
    end
    logger.info "------ LOCK #{obj_name}: FAILED: #{self.class}.#{id} locked by #{lock.locked_by} on #{lock.lock_time}"
    false
  end

  def unlock
    obj_name = "#{self.class}[#{id}]"
    logger.info "------ LOCK #{obj_name}: RELEASED"
    lock.destroy if lock
  end

end
