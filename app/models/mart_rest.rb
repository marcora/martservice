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

    if ['msd', 'interaction', 'complex', 'reaction', 'pathway'].include? dataset_name
      csv = post('/', :body => { :query => xml.to_s, :format => :plain}).to_s
      count += post('/', :body => { :query => xml.to_s.gsub(/count="."/i, 'count="1"') }, :format => :plain).to_i
      keys = xml.find("/Query/Dataset/Attribute").map { |attribute| attribute['name'] }
      FasterCSV.parse(csv) { |values| rows << Hash[*keys.zip(values).flatten] }
    else
      panc_dataset_name = dataset_name[0..-5]+'panc'
      brst_dataset_name = dataset_name[0..-5]+'brst'
      if cancer_type
        # one query
        dataset_name = dataset_name[0..-5]+{ 'pancreatic' => 'panc', 'breast' => 'brst' }[cancer_type]
        q = xml.to_s.gsub(original_dataset_name, dataset_name)
        q = reactomize_query(q, original_dataset_name)
        csv = post('/', :body => { :query => q, :format => :plain}).to_s
        count += post('/', :body => { :query => q.gsub(/count="."/i, 'count="1"') }, :format => :plain).to_i
        xml = XML::Document.string(q)
        keys = xml.find("/Query/Dataset/Attribute").map { |attribute| attribute['name'] }
        FasterCSV.parse(csv) { |values| rows << Hash[*keys.zip(values).flatten] }
        rows.each { |row| row['cancer_type'] = cancer_type } if cancer_type_attribute_requested
      else
        # union of two queries
        # panc rows
        q = xml.to_s.gsub(original_dataset_name, panc_dataset_name)
        q = reactomize_query(q, original_dataset_name)
        csv = post('/', :body => { :query => q, :format => :plain}).to_s
        count += post('/', :body => { :query => q.gsub(/count="."/i, 'count="1"') }, :format => :plain).to_i
        xml = XML::Document.string(q)
        keys = xml.find("/Query/Dataset/Attribute").map { |attribute| attribute['name'] }
        FasterCSV.parse(csv) { |values| rows << Hash[*keys.zip(values).flatten] }
        rows.each { |row| row['cancer_type'] = 'pancreatic' unless row['cancer_type'] } if cancer_type_attribute_requested

        # brst rows
        q = xml.to_s.gsub(original_dataset_name, brst_dataset_name)
        q = reactomize_query(q, original_dataset_name)
        csv = post('/', :body => { :query => q, :format => :plain}).to_s
        count += post('/', :body => { :query => q.gsub(/count="."/i, 'count="1"') }, :format => :plain).to_i
        xml = XML::Document.string(q)
        keys = xml.find("/Query/Dataset/Attribute").map { |attribute| attribute['name'] }
        FasterCSV.parse(csv) { |values| rows << Hash[*keys.zip(values).flatten] }
        rows.each { |row| row['cancer_type'] = 'breast' unless row['cancer_type'] } if cancer_type_attribute_requested
      end
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
    unless ['msd', 'interaction', 'complex', 'reaction', 'pathway'].include? dataset_name
      if cancer_type_attribute_requested
        columns.unshift({ :header => 'Cancer Type', :id => 'cancer_type', :dataIndex => 'cancer_type' })
        fields.unshift({ :name => 'cancer_type' })
      end
    end

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

    # TODO: do same as query method to return proper results
    filters = xml.find("/Query/Dataset/Filter").map { |filter| filter['name'] }
    if filters.include? "cancer_type"
      filter = xml.find_first("/Query/Dataset/Filter[@name='cancer_type']")
      filter.remove!
    end

    format = xml.find_first("/Query")['formatter'].downcase
    results = post('/', :body => { :query => xml.to_s, :format => :plain})
    return results, format
  end

  def self.configuration(dataset_name)
    get('/', :query => { :type => 'configuration', :dataset => dataset }, :format => :xml)
  end


  private

  def self.reactomize_query(query, dataset_name)

    xml = XML::Document.string(query)

    attributes = xml.find("/Query/Dataset/Attribute").map { |attribute| attribute['name'] }
    reactome_attributes = []
    attributes_reactome_dataset_name = nil

    filters = xml.find("/Query/Dataset/Filter").map { |filter| filter['name'] }
    reactome_filters = []
    filters_reactome_dataset_name = nil

    ms = MartSoap.new
    ms.attributes(dataset_name).each { |root|
      root[:groups].each { |group|
        if group[:name] == 'reactome'
          group[:collections].each { |collection|
            if collection[:name] =~ /^\S*(pathway|reaction|interaction|complex)\S*$/i
              collection[:attributes].each { |attribute|
                if (attributes.include? attribute[:name]) && !(reactome_attributes.include? attribute[:name])
                  reactome_attributes << attribute
                  attributes_reactome_dataset_name = $1
                  xml.find_first("/Query/Dataset/Attribute[@name='#{attribute[:name]}']").remove!
                end
              }
            end
          }
        end
      }
    }
    ms.filters(dataset_name).each { |root|
      root[:groups].each { |group|
        if group[:name] == 'reactome'
          group[:collections].each { |collection|
            if collection[:name] =~ /^\S*(pathway|reaction|interaction|complex)\S*$/i
              collection[:filters].each { |filter|
                if (filters.include? filter[:name]) && !(reactome_filters.include? filter[:name])
                  if value = xml.find_first("/Query/Dataset/Filter[@name='#{filter[:name]}']")[:value]
                    reactome_filters << { :name => filter[:name], :value => value } if value
                    filters_reactome_dataset_name = $1
                  end
                  xml.find_first("/Query/Dataset/Filter[@name='#{filter[:name]}']").remove!
                end
              }
            end
          }
        end
      }
    }

    if (attributes_reactome_dataset_name || filters_reactome_dataset_name)
      reactome_dataset = "<Dataset name=\"#{attributes_reactome_dataset_name || filters_reactome_dataset_name}\" interface=\"default\">"
      reactome_attributes.each { |attribute| reactome_dataset += "<Attribute name=\"#{attribute[:name]}\"/>" }
      reactome_filters.each { |filter| reactome_dataset += "<Filter name=\"#{filter[:name]}\" value=\"#{filter[:value]}\"/>" }
      reactome_dataset += "</Dataset>"
      query = xml.to_s.gsub(/(<Query.*>)/i, '\1'+reactome_dataset)
    end
    puts query
    return query
  end
end
