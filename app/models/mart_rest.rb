require 'xml'
require 'httparty'
require 'faster_csv'

class MartRest
  include HTTParty

  base_uri 'http://www.biomart.org:80/biomart/martservice'
  # http_proxy 'wwwcache', 3128 # enable on pweb-3a

  def self.query(xml)
    rows = []
    columns = []
    fields = []
    count = 0
    added_attributes = []
    xml = XML::Document.string(xml)

    dataset_name = xml.find_first("/Query/Dataset")['name']

    csv = post('/', :body => { :query => xml.to_s, :format => :plain}).to_s
    count += post('/', :body => { :query => xml.to_s.gsub(/count="."/i, 'count="1"') }, :format => :plain).to_i
    keys = xml.find("/Query/Dataset/Attribute").map { |attribute| attribute['name'] }
    FasterCSV.parse(csv) { |values| rows << Hash[*keys.zip(values).flatten] }

    ms = MartSoap.new
    ms.attributes(dataset_name).each { |root|
      root[:groups].each { |group|
        group[:collections].each { |collection|
          collection[:attributes].each { |attribute|
            if (keys.include? attribute[:name]) && !(added_attributes.include? attribute[:name])
              columns << { :header => attribute[:display_name] || attribute[:name], :id => attribute[:name], :dataIndex => attribute[:name] }
              fields << { :name => attribute[:name] }
              added_attributes << attribute[:name]
            end
          }
        }
      }
    }

    return { :columns => columns, :fields => fields, :rows => rows, :count => count }
  end

  def self.save_search(xml)
    xml = XML::Document.string(xml)
    format = xml.find_first("/Query")['formatter'].downcase
    search = xml.to_s
    return search, format
  end

  def self.save_results(xml)
    xml = XML::Document.string(xml)
    format = xml.find_first("/Query")['formatter'].downcase
    results = post('/', :body => { :query => xml.to_s, :format => :plain})
    return results, format
  end

  def self.configuration(dataset_name)
    get('/', :query => { :type => 'configuration', :dataset => dataset }, :format => :xml)
  end

end
