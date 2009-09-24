require 'xml'
require 'httparty'
require 'faster_csv'

class MartRest
  include HTTParty

  base_uri 'http://bm-test.res.oicr.on.ca:9009/biomart/martservice'
  # http_proxy 'wwwcache', 3128 # enable on pweb-3a

  def self.query(xml)
    rows = []
    columns = []
    fields = []
    count = 0
    added_attributes = []
    xml = XML::Document.string(xml)
    ###################################################################################
    cancer_type = nil
    filters = xml.find("/Query/Dataset/Filter").map { |filter| filter['name'] }
    if filters.include? "cancer_type"
      filter = xml.find_first("/Query/Dataset/Filter[@name='cancer_type']")
      cancer_type = filter['value'] if ['pancreatic','breast'].include? filter['value']
      filter.remove!
    end

    cancer_type_attribute_requested = false
    attributes = xml.find("/Query/Dataset/Attribute").map { |attribute| attribute['name'] }
    if attributes.include? "cancer_type"
      attribute = xml.find_first("/Query/Dataset/Attribute[@name='cancer_type']")
      cancer_type_attribute_requested = true
      attribute.remove!
    end

    original_dataset_name = dataset_name = xml.find_first("/Query/Dataset")['name']
    panc_dataset_name = dataset_name[0..-5]+'panc'
    brst_dataset_name = dataset_name[0..-5]+'brst'

    if cancer_type
      # one query
      dataset_name = dataset_name[0..-5]+{ 'pancreatic' => 'panc', 'breast' => 'brst' }[cancer_type]
      csv = post('/', :body => { :query => xml.to_s.gsub(original_dataset_name, dataset_name), :format => :plain}).to_s
      count += post('/', :body => { :query => xml.to_s.gsub(/count="."/i, 'count="1"') }, :format => :plain).to_i
      keys = xml.find("/Query/Dataset/Attribute").map { |attribute| attribute['name'] }
      FasterCSV.parse(csv) { |values| rows << Hash[*keys.zip(values).flatten] }
      rows.each { |row| row['cancer_type'] = cancer_type } if cancer_type_attribute_requested
      puts dataset_name
    else
      # union of two queries
      # panc rows
      csv = post('/', :body => { :query => xml.to_s.gsub(original_dataset_name, panc_dataset_name), :format => :plain}).to_s
      count += post('/', :body => { :query => xml.to_s.gsub(/count="."/i, 'count="1"') }, :format => :plain).to_i
      keys = xml.find("/Query/Dataset/Attribute").map { |attribute| attribute['name'] }
      FasterCSV.parse(csv) { |values| rows << Hash[*keys.zip(values).flatten] }
      rows.each { |row| row['cancer_type'] = 'pancreatic' unless row['cancer_type'] } if cancer_type_attribute_requested
      puts panc_dataset_name

      # brst rows
      csv = post('/', :body => { :query => xml.to_s.gsub(original_dataset_name, brst_dataset_name), :format => :plain}).to_s
      count += post('/', :body => { :query => xml.to_s.gsub(/count="."/i, 'count="1"') }, :format => :plain).to_i
      keys = xml.find("/Query/Dataset/Attribute").map { |attribute| attribute['name'] }
      FasterCSV.parse(csv) { |values| rows << Hash[*keys.zip(values).flatten] }
      rows.each { |row| row['cancer_type'] = 'breast' unless row['cancer_type'] } if cancer_type_attribute_requested
      puts brst_dataset_name
    end

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

    # add virtual cancer type attribute
    if cancer_type_attribute_requested
      columns.unshift({ :header => 'Cancer Type', :id => 'cancer_type', :dataIndex => 'cancer_type' })
      fields.unshift({ :name => 'cancer_type' })
    end

    ###################################################################################

    # # assume csv formatter, to_s is important here!
    # csv = post('/', :body => { :query => xml.to_s, :format => :plain}).to_s
    # count = post('/', :body => { :query => xml.to_s.gsub(/count="."/i, 'count="1"') }, :format => :plain).to_i
    # keys = xml.find("/Query/Dataset/Attribute").map { |attribute| attribute['name'] }
    # dataset_name = xml.find_first("/Query/Dataset")['name']
    # FasterCSV.parse(csv) { |values| rows << Hash[*keys.zip(values).flatten] }

    # ms = MartSoap.new
    # ms.attributes(dataset_name).each { |root|
    #   root[:groups].each { |group|
    #     group[:collections].each { |collection|
    #       collection[:attributes].each { |attribute|
    #         if (keys.include? attribute[:name]) && !(added_attributes.include? attribute[:name])
    #           columns << { :header => attribute[:display_name] || attribute[:name], :id => attribute[:name], :dataIndex => attribute[:name] }
    #           fields << { :name => attribute[:name] }
    #           added_attributes << attribute[:name]
    #         end
    #       }
    #     }
    #   }
    # }

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
    ###########################################################################
    # TODO: do same as query method to return proper results
    filters = xml.find("/Query/Dataset/Filter").map { |filter| filter['name'] }
    if filters.include? "cancer_type"
      filter = xml.find_first("/Query/Dataset/Filter[@name='cancer_type']")
      filter.remove!
    end
    ###########################################################################
    format = xml.find_first("/Query")['formatter'].downcase
    results = post('/', :body => { :query => xml.to_s, :format => :plain})
    return results, format
  end

  def self.configuration(dataset)
    get('/', :query => { :type => 'configuration', :dataset => dataset }, :format => :xml)
  end

end
