module TranslationMemoryImporter
  class FileFetcher

    LOCAL_PATH = '/home/edi/xta'.freeze

    def initialize(full_filename, filename, from_remote = false)
      @from_remote = from_remote
      @full_filename = full_filename
      @filename = filename
    end

    def fetch
      if @from_remote
        command = "scp root@74.50.55.135:#{@full_filename.sub(/.+?(?=private)/, '/root/rails_apps/icanlocalize/shared/')} #{LOCAL_PATH}"
        system command
        path = "#{LOCAL_PATH}/#{@filename}"
      else
        path = @full_filename
        # path = "#{LOCAL_PATH}/#{@filename}"
      end
      current_data = File.read(path)
      dat = StringIO.new(current_data)
      begin
        gz = Zlib::GzipReader.new(dat)
        gz.read
      rescue Zlib::GzipFile::Error => e
        raise e
      end
    end

    def self.fetch_from_production(cms, log)
      file_path = cms.translated_xliff.full_filename
      folders = file_path.split('/')
      feed = '/'
      1.upto(folders.size - 2) do |i|
        feed << folders[i]
        system "mkdir #{feed}" unless Dir.exist?(feed)
        feed << '/' unless i == (folders.size - 2)
      end
      production_path = file_path.sub(/.+?(?=xliffs)/, '/home/icl/rails_apps/icanlocalize/shared/private/production/')
      log.info("We are fetching #{production_path} to #{feed}")
      system "scp icl@icanlocalize.com:#{production_path} #{feed}"
      cms.translated_xliff.get_contents
    end

  end
end
