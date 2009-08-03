require 'httparty'

class MartService
  include HTTParty
  base_uri 'www.biomart.org/biomart/martservice'
  format :xml

  def self.configuration(dataset)
    get('/', :query => {:type => 'configuration', :dataset => dataset})
  end
end

class RootController < ApplicationController
  def index
    ms = MartSoap.new
    
    case params[:type]
    when 'registry'
      xml = ms.marts()
    when 'datasets'
      xml = ms.datasets(params[:mart])
    when 'configuration'
      xml = MartService.configuration(params[:dataset])
    when 'attributes'
      xml = ms.attributes(params[:dataset])
    when 'filters'
      xml = ms.filters(params[:dataset])
    else
      return
    end

    render :json => { :rows => xml }, :callback => params[:callback]
  end
end
