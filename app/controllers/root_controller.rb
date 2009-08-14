class RootController < ApplicationController
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
      data = MartSolr.search(params[:q])
    end
    if data
      render :json => data, :callback => params[:callback]
    else
      render :text => params.inspect
    end
  end
end
