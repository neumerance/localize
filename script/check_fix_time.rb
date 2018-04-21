class CheckFixTime
  @@logger = Logger.new("#{Rails.root}/log/verify_times.log")
  FIX_WITH_TIME = Time.now-2.days

  def self.verify
    models = self.models
    models.each do |m|
      if m.try(:superclass).try(:name) == "ApplicationRecord" && m.column_names.include?("created_at")
        @@logger.info "#{m} -> #{m.where(created_at: nil).size}"
      end
    end
  end

  # def self.fix
  #   models = self.models
  #   models.each do |m|
  #     if m.try(:superclass).try(:name) == "ApplicationRecord" && m.column_names.include?("created_at")
  #       if m.where(created_at: nil).size > 0
  #         @@logger.info("Going to fix #{m}")
  #         puts "Going to fix #{m}"
  #         self.apply_fix(m)
  #       end
  #     end
  #   end
  # end

  def self.apply_fix(m)
    @@logger.info("---------START FIXING #{m}---------------")
    via_next_record = 0
    via_timestamp = 0
    bad_records = m.where(created_at: nil)
    bad_records.each do |r|
      @@logger.info("Fixing #{m}, record with id: #{r.id}")
      nr = self.find_next_good_record(m,r)
      if nr
        @@logger.info("Found next record with id #{nr.id} and created_at #{nr.created_at}")
        r.update_column(:created_at, nr.created_at)
        @@logger.info("Fixed #{m}, record with id: #{r.id} using next record")
        via_next_record +=1
      else
        @@logger.info("Next record not found. Goint to fix via timestamp")
        r.update_column(:created_at, FIX_WITH_TIME)
        @@logger.info("Fixed #{m}, record with id: #{r.id} using timestamp")
        via_timestamp +=1
      end
    end
    @@logger.info("#{m} fixed using: next record -> #{via_next_record} and timestamp -> #{via_timestamp}")
    @@logger.info("---------FINISHED FIXING #{m}---------------")
  end

  def self.find_next_good_record(m,r)
    m.where("id > ? and created_at is not null", r.id).order(:id).first
  end

  def self.models
    models = []
    Dir.foreach("#{Rails.root}/app/models") do |model_path|
      begin
      cl = model_path.split(".")[0].camelize.constantize
      models << cl
      rescue Exception
        puts "Failed on #{model_path}"
      end
    end
    models
  end

end