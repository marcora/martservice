require 'hpricot'
require 'httparty'
require 'faster_csv'

class Hash
  def fetch_all(key)
    return [] if not self.has_key?(key)
    value = self.fetch(key)
    [ value ] + [ value ].fetch_all(key)
  end
end

class Array
  def fetch_all(key)
    self.find_all{|x| x.respond_to? :fetch_all} \
      .map{|x| x.fetch_all(key) } \
      .inject( [] ){|a,b| a + b }
  end
end

class MartHttp
  include HTTParty

  base_uri 'www.biomart.org/biomart/martservice'

  def self.query(params)
    rows = []
    columns = []
    fields = []
    # assume csv formatter, to_s is important here!
    csv = post('/', :body => { :query => params[:xml], :format => :plain}).to_s
    count = post('/', :body => { :query => params[:xml].gsub(/count="."/i, 'count="1"') }, :format => :plain).to_i
    xml = Hpricot(params[:xml]) # this line should go first to validate xml, however then xml.to_s spits out well formed xml that biomart service complains about! :(
    keys = xml.search("/Query/Dataset/Attribute").map { |attr| attr['name'] }
    FasterCSV.parse(csv) { |values| rows << Hash[*keys.zip(values).flatten] }
    ms = MartSoap.new
    ms.attributes('msd').each { |root|
      root[:groups].each { |group|
        group[:collections].each { |collection|
          collection[:attributes].each { |attribute|
            if keys.include? attribute[:name]
              columns << { :header => attribute[:display_name] || attribute[:name], :width => 100, :id => attribute[:name] }
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
