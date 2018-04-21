module CmsActions
  module Parsing
    class FixTransUnitStatus
      def call(xliff_trans_unit:, force_import: false)
        xliff_trans_unit.target_mrks.each { |target_mrk| fix_target_mrk_status(target_mrk, force_import) }
      end

      private

      def fix_target_mrk_status(target_mrk, force_import = false)
        if force_import
          case target_mrk.mrk_status
          when TranslatedMemory::TM_SOURCE[:imported_error]
            target_mrk.mrk_status = XliffTransUnitMrk::MRK_STATUS[:original]
          when TranslatedMemory::TM_SOURCE[:imported_problems]
            target_mrk.mrk_status = XliffTransUnitMrk::MRK_STATUS[:in_progress]
          when TranslatedMemory::TM_SOURCE[:imported_success]
            target_mrk.mrk_status = XliffTransUnitMrk::MRK_STATUS[:translation_completed]
          end
          target_mrk.content = target_mrk.source_mrk.content
        elsif need_to_fix_status?(target_mrk)
          target_mrk.mrk_status = XliffTransUnitMrk::MRK_STATUS[:original]
          target_mrk.content = target_mrk.source_mrk.content
        end
        sync_top_content_with_status(target_mrk)
        target_mrk.save!
      end

      def sync_top_content_with_status(target_mrk)
        target_mrk.top_content = target_mrk.top_content.sub(/(?<=mstatus=")-\d/, target_mrk.mrk_status.to_s)
      end

      def need_to_fix_status?(target_mrk)
        # import statuses(-1, -2, -3) should be fixed to 0
        target_mrk.mrk_status < 0
      end
    end
  end
end
