require 'hpricot'
require 'httparty'
require 'csv'

class MartHttp
  include HTTParty

  base_uri 'www.biomart.org/biomart/martservice'

  def self.query(query)
    # assume csv formatter
    csv = post('/', :body => { :query => query }, :format => :plain).to_s
    rows = []
    query = Hpricot(query)
    keys = query.search("/Query/Dataset/Attribute").map { |attr| attr['name'] }
    CSV.parse(csv) { |values| rows << Hash[*keys.zip(values).flatten] }
    rows
  end

  def self.configuration(dataset)
    get('/', :query => { :type => 'configuration', :dataset => dataset }, :format => :xml)
  end
end
