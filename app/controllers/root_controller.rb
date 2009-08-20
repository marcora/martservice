class RootController < ApplicationController

  skip_before_filter :verify_authenticity_token
  
  def index
    data = nil
    ms = MartSoap.new
    case params[:type]
    when 'registry'
      data = ms.marts()
    when 'datasets'
      data = ms.datasets(params[:mart])
    when 'configuration'
      data = MartRest.configuration(params[:dataset])
    when 'attributes'
      data = ms.attributes(params[:dataset])
    when 'filters'
      data = ms.filters(params[:dataset])
    when 'query'
      data = MartRest.query(params[:xml])
    when 'search'
      facet_fields = []
      facet_fields = params[:facet_fields].split('|') if params[:facet_fields]
      filters = []
      filters = params[:filters].split('|') if params[:filters]
      data = MartSolr.search(params[:q], facet_fields, filters)
    end
    if data
      render :json => data, :callback => params[:callback]
    else
      render :text => params.inspect
    end
  end
end
