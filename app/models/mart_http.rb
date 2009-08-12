require 'hpricot'
require 'httparty'
require 'csv'

class MartHttp
  include HTTParty

  base_uri 'www.biomart.org/biomart/martservice'

  def self.query(xml)
    rows = []
    # assume csv formatter, to_s is important here!
    csv = post('/', :body => { :query => xml }, :format => :plain).to_s
    xml = Hpricot(xml)
    keys = xml.search("/Query/Dataset/Attribute").map { |attr| attr['name'] }
    CSV.parse(csv) { |values| rows << Hash[*keys.zip(values).flatten] }
    rows
  end

  def self.configuration(dataset)
    get('/', :query => { :type => 'configuration', :dataset => dataset }, :format => :xml)
  end
end
