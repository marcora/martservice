class RootController < ApplicationController
  def index
    ms = MartSoap.new
    data = nil
    case params[:type]
    when 'registry'
      data = ms.marts()
    when 'datasets'
      data = ms.datasets(params[:mart])
    when 'configuration'
      data = MartHttp.configuration(params[:dataset])
    when 'attributes'
      data = ms.attributes(params[:dataset])
    when 'filters'
      data = ms.filters(params[:dataset])
    when 'query'
      data = MartHttp.query(params[:query])
    end
    if data
      render :json => { :rows => data }, :callback => params[:callback]
    end
  end
end
