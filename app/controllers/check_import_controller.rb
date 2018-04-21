class CheckImportController < ApplicationController

  def index
    @cms_id = nil
    @source_language = nil
    @target_language = nil
    @mrks = nil
    @languages = Language.all

    if params[:sent].present?
      @cms_id = params[:cms_request_id] unless params[:cms_request_id].blank?

      @source_language = params[:source_language].to_i unless params[:source_language] == '0'
      @target_language = params[:target_language].to_i unless params[:target_language] == '0'

      @mrks = query_markers(@cms_id, @source_language, @target_language)
    end
  end

  private

  def query_markers(cms_id, source_language, target_language)
    query = <<SQL
      SELECT ms.cms_request_id,
             ms.id as source_id,
             mt.mrk_status as mrk_status,
             ms.content as source_content,
             mt.content as target_content,
             mt.id as target_id
      FROM `xliff_trans_unit_mrks` as ms
      INNER JOIN xliff_trans_unit_mrks as mt on ms.target_id = mt.id where ms.mrk_type=0
SQL
    query += " and ms.cms_request_id = #{cms_id}" if cms_id.present?
    query += " and ms.language_id = #{source_language}" if source_language.present?
    query += " and mt.language_id = #{target_language}" if target_language.present?
    XliffTransUnitMrk.find_by_sql(query)
  end

end
