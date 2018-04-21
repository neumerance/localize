namespace :managed_works do
  desc 'clean all managed work orphan records'
  task clean_orphan_records: :environment do
    batch_size = 10_000

    count = ManagedWork.count
    ap "Processing #{count} ManagedWorks"

    times = []
    backup = []
    kinds = {}

    ManagedWork.find_in_batches(batch_size: batch_size) do |group|
      puts "ManagedWorks left: #{count}"

      destroyed = 0

      times << Benchmark.realtime do
        group.each do |managed_work|
          next unless managed_work.owner.nil?
          backup << managed_work.attributes

          kinds[managed_work.owner_type] ||= 0
          kinds[managed_work.owner_type] += 1

          managed_work.destroy
          destroyed += 1
        end
      end

      count -= batch_size

      average_per_batch = (times.sum / times.count).to_i
      batches_left = count / 1000

      estimated_time = Time.at(average_per_batch * batches_left).utc.strftime('%H:%M')
      puts "... done in #{times.last.to_i}s. #{destroyed} items deleted. Estimated time left: #{estimated_time} hours"
    end

    puts "DONE: #{backup.count} items deleted"
    kinds.each { |kind, amount| puts "  #{kind}: #{amount}" }

    File.open('/tmp/orphan_mw_backup.yml', 'w') do |f|
      f << backup.to_yaml
    end
  end
end
