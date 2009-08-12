class RootController < ApplicationController
  def index
    rows = nil
    ms = MartSoap.new
    case params[:type]
    when 'registry'
      rows = ms.marts()
    when 'datasets'
      rows = ms.datasets(params[:mart])
    when 'configuration'
      rows = MartHttp.configuration(params[:dataset])
    when 'attributes'
      rows = ms.attributes(params[:dataset])
    when 'filters'
      rows = ms.filters(params[:dataset])
    when 'query'
      rows = MartHttp.query(params[:xml])
    end
    if rows
      render :json => { :rows => rows }, :callback => params[:callback]
    end
  end
end
