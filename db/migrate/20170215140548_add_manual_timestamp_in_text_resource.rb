class AddManualTimestampInTextResource < ActiveRecord::Migration[5.0]

  def self.up
    add_column :text_resources, :mcat, :timestamp, default:nil
    add_column :text_resources, :muat, :timestamp, default:nil
    execute 'UPDATE text_resources set created_at=updated_at where created_at is null and updated_at is not null;'
    execute 'UPDATE text_resources set mcat=created_at, muat=updated_at;'
    TextResource.where(mcat: nil).update_all(mcat: Time.now)
    TextResource.where(muat: nil).update_all(muat: Time.now)
    TextResource.where(created_at: nil).each do |w|
      next_w = TextResource.where("id > ? and created_at is not null", w.id).order(:id).first
      if next_w
        w.update_column(:created_at, next_w.created_at)
      else
        w.update_column(:created_at, Time.now)
      end
    end
  end

  def self.down
    remove_column :text_resources, :mcat
    remove_column :text_resources, :muat
  end

end
