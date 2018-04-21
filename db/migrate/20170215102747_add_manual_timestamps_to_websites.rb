class AddManualTimestampsToWebsites < ActiveRecord::Migration[5.0]

  def self.up
    add_column :websites, :mcat, :timestamp, default:nil
    add_column :websites, :muat, :timestamp, default:nil
    execute 'UPDATE websites set created_at=updated_at where created_at is null and updated_at is not null;'
    execute 'UPDATE websites set mcat=created_at, muat=updated_at;'
    Website.where(mcat: nil).update_all(mcat: Time.now)
    Website.where(muat: nil).update_all(muat: Time.now)
    Website.where(created_at: nil).each do |w|
      next_w = Website.where("id > ? and created_at is not null", w.id).order(:id).first
      if next_w
        w.update_column(:created_at, next_w.created_at)
      else
        w.update_column(:created_at, Time.now)
      end
    end
  end

  def self.down
    remove_column :websites, :mcat
    remove_column :websites, :muat
  end

end
