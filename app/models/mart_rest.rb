require 'hpricot'
require 'httparty'
require 'faster_csv'

class MartRest
  include HTTParty

  base_uri 'www.biomart.org/biomart/martservice'

  def self.query(xml)
    rows = []
    columns = []
    fields = []
    # assume csv formatter, to_s is important here!
    csv = post('/', :body => { :query => xml, :format => :plain}).to_s
    count = post('/', :body => { :query => xml.gsub(/count="."/i, 'count="1"') }, :format => :plain).to_i
    xml = Hpricot(xml) # this line should go first to validate xml, however then xml.to_s spits out well formed xml that biomart service complains about! :(
    keys = xml.search("/Query/Dataset/Attribute").map { |attribute| attribute['name'] }
    dataset_name = xml.search("/Query/Dataset").map { |dataset| dataset['name'] }.first()
    FasterCSV.parse(csv) { |values| rows << Hash[*keys.zip(values).flatten] }
    ms = MartSoap.new
    ms.attributes(dataset_name).each { |root|
      root[:groups].each { |group|
        group[:collections].each { |collection|
          collection[:attributes].each { |attribute|
            if keys.include? attribute[:name]
              columns << { :header => attribute[:display_name] || attribute[:name], :width => 100, :id => attribute[:name], :dataIndex => attribute[:name] }
              fields << { :name => attribute[:name] }
            end
          }
        }
      }
    }
    return { :columns => columns, :fields => fields, :rows => rows, :count => count }
  end
  
  def self.configuration(dataset)
    get('/', :query => { :type => 'configuration', :dataset => dataset }, :format => :xml)
  end
end
