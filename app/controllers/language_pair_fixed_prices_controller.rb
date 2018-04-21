class LanguagePairFixedPricesController < ApplicationController

  before_action :get_resource

  def index
    query = 'SELECT l.id,
                    fl.name,
                    tl.name,
                    l.number_of_transactions,
                    l.calculated_price,
                    l.number_of_transactions_last_year,
                    l.calculated_price_last_year,
                    l.updated_at,
                    l.actual_price,
                    l.published,
                    COUNT(t.id) AS translators
              FROM language_pair_fixed_prices AS l
                LEFT OUTER JOIN translator_languages_auto_assignments AS t
                  ON l.language_pair_id = t.language_pair_id
                INNER JOIN languages AS fl
                  ON l.from_language_id = fl.id
                INNER JOIN languages AS tl
                  ON l.to_language_id = tl.id
              GROUP BY t.language_pair_id, l.id
              ORDER BY translators DESC'
    data = ActiveRecord::Base.connection.execute(query).to_a.map do |row|
      {
        from: row[1],
        to: row[2],
        actual_price: row[8],
        calculated_price: row[4],
        calculated_price_last_year: row[6],
        number_of_transactions: row[3],
        number_of_transactions_last_year: row[5],
        published: row[9],
        number_of_translators: row[10],
        id: row[0]
      }
    end
    respond_to do |format|
      format.html
      format.json { render json: { data: data } }
    end
  end

  def update
    current_price = @resource.actual_price
    new_price = params[:language_pair_fixed_price][:actual_price]
    translators_opted_in_for_autoassign = @resource.auto_assignable_translators.count > 0
    if new_price.present? && new_price != current_price && translators_opted_in_for_autoassign
      flash.now[:notice] = 'Cannot update the price of a language pair after ' \
        'translators have opted-in to be automatically assigned. If you ' \
        'really need to do that, please ask the development team to ' \
        'implement icldev-2558.'
      params[:language_pair_fixed_price][:actual_price] = current_price
    end

    @resource.update_attributes(params[:language_pair_fixed_price])
  end

  def update_field; end

  def language_price_details_translators
    translators = @resource.translators
    respond_to do |format|
      format.html
      format.json { render json: { data: translators } }
    end
  end

  private

  def get_resource
    @resource = LanguagePairFixedPrice.find(params[:id]) unless params[:id].nil?
  end

end
