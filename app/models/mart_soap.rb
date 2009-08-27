require 'handsoap'

MARTSOAP_ENDPOINT = {
  :uri => 'http://www.biomart.org/biomart/martsoap',
  :version => 1
}

JSON_DIR = "/Users/marcora/Projects/biomart/martview/json"

# Handsoap.http_driver = :httpclient # uncomment if using jruby!

def filterize(filter)
  children = []
  if filter[:groups]
    children = filter[:groups]
    filter.delete(:groups)
  elsif filter[:collections]
    children = filter[:collections]
    filter.delete(:collections)
  elsif filter[:filters]
    children = filter[:filters]
    filter.delete(:filters)
  end
  filter.merge({ :id => rand(36**8).to_s(36), :text => filter[:display_name] || filter[:name], :children => (children.map { |child| attributize(child) } unless children.empty?), :leaf => children.empty? })
end

def attributize(attribute)
  children = []
  if attribute[:groups]
    children = attribute[:groups]
    attribute.delete(:groups)
  elsif attribute[:collections]
    children = attribute[:collections]
    attribute.delete(:collections)
  elsif attribute[:attributes]
    children = attribute[:attributes]
    attribute.delete(:attributes)
  end
  attribute.merge({ :id => rand(36**8).to_s(36), :text => attribute[:display_name] || attribute[:name], :children => (children.map { |child| attributize(child) } unless children.empty?), :leaf => children.empty? })
end

class MartSoap < Handsoap::Service

  def create_static_json_files
    marts_and_datasets = []

    self.marts().each_with_index { |mart, index|
      marts_and_datasets << mart.merge!({ :itemId => mart[:name], :text => mart[:display_name] || mart[:name], :iconCls => 'mart_icon', :menu => [] })

      self.datasets(mart[:name]).each { |dataset|
        marts_and_datasets[index][:menu] << dataset.merge!({ :itemId => dataset[:name], :text => dataset[:display_name] || dataset[:name], :iconCls => 'dataset_icon',
                                                             :menu => [{
                                                                         :itemId => 'simple', :text => 'Simple', :iconCls => 'simple_search_icon',
                                                                         :mart_name => mart[:name], :mart_display_name => mart[:display_name] || mart[:name],
                                                                         :dataset_name => dataset[:name], :dataset_display_name => dataset[:display_name] || dataset[:name],
                                                                         :search_name => 'simple', :search_display_name => 'Simple',
                                                                         :results_name => 'tabular'
                                                                       },
                                                                       {
                                                                         :itemId => 'guided', :text => 'Guided', :iconCls => 'guided_search_icon',
                                                                         :mart_name => mart[:name], :mart_display_name => mart[:display_name] || mart[:name],
                                                                         :dataset_name => dataset[:name], :dataset_display_name => dataset[:display_name] || dataset[:name],
                                                                         :search_name => 'guided', :search_display_name => 'Guided',
                                                                         :results_name => 'tabular'
                                                                       },
                                                                       {
                                                                         :itemId => 'advanced', :text => 'Advanced', :iconCls => 'advanced_search_icon',
                                                                         :mart_name => mart[:name], :mart_display_name => mart[:display_name] || mart[:name],
                                                                         :dataset_name => dataset[:name], :dataset_display_name => dataset[:display_name] || dataset[:name],
                                                                         :search_name => 'advanced', :search_display_name => 'Advanced',
                                                                         :results_name => 'tabular'
                                                                       },
                                                                       {
                                                                         :itemId => 'user', :text => 'High-res NMR structures of dimers', :iconCls => 'user_search_icon',
                                                                         :mart_name => mart[:name], :mart_display_name => mart[:display_name] || mart[:name],
                                                                         :dataset_name => dataset[:name], :dataset_display_name => dataset[:display_name] || dataset[:name],
                                                                         :search_name => 'user', :search_display_name => 'High-res NMR structures of dimers',
                                                                         :results_name => 'tabular'
                                                                       }]
                                                           })

        # for each dataset write filters and attributes static json files
        filename = "#{JSON_DIR}/#{mart[:name]}.#{dataset[:name]}.json"
        json = { :filters => self.filters(dataset[:name]).map { |filter| filterize(filter) }, :attributes => self.attributes(dataset[:name]).map { |attribute| attributize(attribute) } }.to_json
        File.open(filename, 'w') { |f| f.write(json) }
      }
      break if index > 9 # FIX: Uncomment to fetch all datasets
    }

    # write marts_and_datasets static json file
    filename = "#{JSON_DIR}/marts_and_datasets.json"
    json = marts_and_datasets.to_json
    File.open(filename, 'w') { |f| f.write(json) }
  end


  endpoint MARTSOAP_ENDPOINT

  on_create_document do |doc|
    doc.alias 'ns', "http://www.biomart.org:80/MartServiceSoap"
  end

  def marts()
    response = invoke("ns:getRegistry", :soap_action => :none)
    node = response.document.xpath('//ns:mart', ns).map { |node| parse_mart(node) }
  end

  def datasets(mart_name)
    response = invoke("ns:getDatasets", :soap_action => :none) do |message|
      message.add 'ns:martName', mart_name
    end
    node = response.document.xpath('//ns:datasetInfo', ns).map { |node| parse_dataset(node) }
  end

  def attributes(dataset_name, virtual_schema='default')
    response = invoke("ns:getAttributes", :soap_action => :none) do |message|
      message.add 'ns:datasetName', dataset_name
      message.add 'ns:virtualSchema', virtual_schema
    end
    node = response.document.xpath('//ns:attributePage', ns).map { |node| parse_attribute_page(node) }
  end

  def filters(dataset_name, virtual_schema='default')
    response = invoke("ns:getFilters", :soap_action => :none) do |message|
      message.add 'ns:datasetName', dataset_name
      message.add 'ns:virtualSchema', virtual_schema
    end
    node = response.document.xpath('//ns:filterPage', ns).map { |node| parse_filter_page(node) }
  end


  private

  def ns; { 'ns' => 'http://www.biomart.org:80/MartServiceSoap' }; end

  # marts

  def parse_mart(node)
    {
      :name => xml_to_str(node, './ns:name/text()'),
      :display_name => xml_to_str(node, './ns:displayName/text()'),
      :database => xml_to_str(node, './ns:database/text()'),
      :host => xml_to_str(node, './ns:host/text()'),
      :path => xml_to_str(node, './ns:path/text()'),
      :port => xml_to_int(node, './ns:port/text()'),
      :visible => xml_to_bool(node, './ns:visible/text()'),
      :default => xml_to_bool(node, './ns:default/text()'),
      :server_virtual_schema => xml_to_str(node, './ns:serverVirtualSchema/text()'),
      :include_datasets => xml_to_str(node, './ns:includeDatasets/text()'),
      :mart_user => xml_to_str(node, './ns:martUser/text()'),
      :redirect => xml_to_bool(node, './ns:redirect/text()'),
    }
  end

  # datasets

  def parse_dataset(node)
    {
      :name => xml_to_str(node, './ns:name/text()'),
      :display_name => xml_to_str(node, './ns:displayName/text()'),
      :type => xml_to_str(node, './ns:type/text()'),
      :visible => xml_to_bool(node, './ns:visible/text()'),
      :interface => xml_to_str(node, './ns:interface/text()'),
    }
  end

  # attributes

  def parse_attribute_page(node)
    {
      :name => xml_to_str(node, './ns:name/text()'),
      :display_name => xml_to_str(node, './ns:displayName/text()'),
      :max_select => xml_to_int(node, './ns:maxSelect/text()'),
      :formatters => xml_to_str(node, './ns:formatters/text()'),
      :groups => node.xpath('./ns:attributeGroup', ns).map { |node| parse_attribute_group(node) }
    }
  end

  def parse_attribute_group(node)
    {
      :name => xml_to_str(node, './ns:name/text()'),
      :display_name => xml_to_str(node, './ns:displayName/text()'),
      :max_select => xml_to_int(node, './ns:maxSelect/text()'),
      :collections => node.xpath('./ns:attributeCollection', ns).map { |node| parse_attribute_collection(node) }
    }
  end

  def parse_attribute_collection(node)
    {
      :name => xml_to_str(node, './ns:name/text()'),
      :display_name => xml_to_str(node, './ns:displayName/text()'),
      :max_select => xml_to_int(node, './ns:maxSelect/text()'),
      :attributes => node.xpath('./ns:attributeInfo', ns).map { |node| parse_attribute(node) }
    }
  end

  def parse_attribute(node)
    {
      :name => xml_to_str(node, './ns:name/text()'),
      :display_name => xml_to_str(node, './ns:displayName/text()'),
      :description => xml_to_str(node, './ns:description/text()'),
      :model_reference => xml_to_str(node, './ns:modelReference/text()'),
    }
  end

  # filters

  def parse_filter_page(node)
    {
      :name => xml_to_str(node, './ns:name/text()'),
      :display_name => xml_to_str(node, './ns:displayName/text()'),
      :groups => node.xpath('./ns:filterGroup', ns).map { |node| parse_filter_group(node) }
    }
  end

  def parse_filter_group(node)
    {
      :name => xml_to_str(node, './ns:name/text()'),
      :display_name => xml_to_str(node, './ns:displayName/text()'),
      :collections => node.xpath('./ns:filterCollection', ns).map { |node| parse_filter_collection(node) }
    }
  end

  def parse_filter_collection(node)
    {
      :name => xml_to_str(node, './ns:name/text()'),
      :display_name => xml_to_str(node, './ns:displayName/text()'),
      :attributes => node.xpath('./ns:filterInfo', ns).map { |node| parse_filter(node) }
    }
  end

  def parse_filter(node)
    {
      :name => xml_to_str(node, './ns:name/text()'),
      :display_name => xml_to_str(node, './ns:displayName/text()'),
      :description => xml_to_str(node, './ns:description/text()'),
      :qualifier => xml_to_str(node, './ns:qualifier/text()'),
      :options => xml_to_str(node, './ns:options/text()'),
      :model_reference => xml_to_str(node, './ns:modelReference/text()'),
    }
  end

end
