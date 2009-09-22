class MartserviceController < ApplicationController
  skip_before_filter :verify_authenticity_token

  def index
    data = nil
    saved_search = nil
    saved_results = nil
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
      filters = filters.map { |filter|
        name = filter.split(':')[0]
        value = filter.split(':')[1]
        if value =~ /^[^"].*\s+.*[^"]$/i
          value = '"' + value + '"'
        end
        name + ':' + value
      }
      data = MartSolr.search(params[:q], facet_fields, filters)
    when 'savesearch'
      saved_search, format = MartRest.save_search(params[:xml])
    when 'saveresults'
      saved_results, format = MartRest.save_results(params[:xml])
    end
    if data
      render :json => data, :callback => params[:callback]
    elsif saved_search
      send_data saved_search, :filename => 'biomart_search.'+format, :disposition => 'attachment', :type => format.to_sym
    elsif saved_results
      send_data saved_results, :filename => 'biomart_results.'+format, :disposition => 'attachment', :type => format.to_sym
    else
      render :text => params.inspect
    end
  end

end
