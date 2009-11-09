DESCRIPTION = "Praesent vitae metus ut ligula congue gravida eu ac odio. Sed porttitor massa ac lectus interdum aliquam. Suspendisse consequat egestas suscipit. Aliquam venenatis elementum velit at ornare. Aliquam erat volutpat. Suspendisse potenti. Vivamus euismod sodales mi, eget adipiscing quam fermentum nec. Morbi ac leo libero. Quisque commodo mollis molestie. Morbi sodales ante et quam facilisis faucibus. Vestibulum urna turpis, dapibus a hendrerit a, luctus at orci."
STOP_WORDS = [ "a","able","about","across","after","all","almost","also","am","among","an","and","any","are","as","at","be","because","been","but","by","can","cannot","could","dear","did","do","does","either","else","ever","every","for","from","get","got","had","has","have","he","her","hers","him","his","how","however","i","if","in","into","is","it","its","just","least","let","like","likely","may","me","might","most","must","my","neither","no","nor","not","of","off","often","on","only","or","other","our","own","rather","said","say","says","she","should","since","so","some","than","that","the","their","them","then","there","these","they","this","tis","to","too","twas","us","wants","was","we","were","what","when","where","which","while","who","whom","why","will","with","would","yet","you","your" ]
KEYWORDS = [ ["genes"],
             ["DNA"],
             ["RNA"],
             ["transcripts"],
             ["proteins"],
             ["genomics"],
             ["proteomics"],
             ["features"],
             ["snps", "variations"],
             ["peptides"],
             ["structures"],
             ["ontology"],
             ["expression"],
             ["anatomy"],
             ["physiology"],
             ["reaction"],
             ["interaction", "complex"],
             ["pathway"],
             ["frog", "xenopus"],
             ["xenopus laevis"],
             ["xenopus tropicalis"],
             ["fly", "drosophila"],
             ["drosophila melanogaster"],
             ["mouse", "mus musculus"],
             ["caenorhabditis elegans", "celegans"],
             ["worm", "caenorhabditis"],
             ["saccharomyces cerevisiae"],
             ["yeast", "budding", "saccharomyces"],
             ["schizosaccharomyces pombe"],
             ["yeast", "fission", "schizosaccharomyces"],
             ["bacteria", "bacterial"],
             ["virus", "viral"],
             ["bacteria", "bacterial", "escherichia coli", "ecoli"],
             ["arabidopsis thaliana"],
             ["fungi", "fungal"],
             ["plant"],
             ["cress", "arabidopsis"],
             ["oryza sativa"],
             ["rice", "oryza"],
             ["zea mays"],
             ["maize", "corn", "zea"],
             ["guinea pig", "cavia porcellus"],
             ["pig", "sus scrofa"],
             ["cow", "bos taurus"],
             ["dog", "canis familiaris"],
             ["cat", "felis catus"],
             ["chicken", "gallus gallus"],
             ["horse", "equus caballus"],
             ["human", "homo sapiens"],
             ["rat", "rattus norvegicus"],
             ["zebrafish", "danio rerio"] ]

def normalize(fulltext)
  normalized_words = []
  # remove stop words
  words = fulltext.downcase.gsub(/\b(#{STOP_WORDS.join('|')})\b/, '').split(/\b/)
  words.each { |word| normalized_words << [word.singularize, word.pluralize] if word =~ /^\w+$/ }
  return normalized_words.flatten.uniq.join(' ')
end

require 'handsoap'

MARTSOAP_ENDPOINT = {
  :uri => 'http://www.biomart.org:80/biomart/martsoap',
  :version => 1
}

JSON_DIR = "/Users/marcora/Projects/biomart/martview/json"

Handsoap.http_driver = :httpclient
Handsoap.xml_query_driver = :libxml

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
  fulltext = []
  fulltext << filter[:display_name]
  fulltext << filter[:name]
  fulltext << filter[:description]
  filter.merge!({ :id => rand(36**8).to_s(36), :text => filter[:display_name] || filter[:name], :fulltext => normalize(fulltext.compact.uniq.join(' ')), :qtipCfg => { :title => filter[:display_name] || filter[:name], :text => filter[:description], :dismissDelay => 0 } })
  if children.empty?
    filter.merge({ :leaf => true, :children => [], :iconCls => 'filter-icon' })
  else
    filter.merge({ :leaf => false, :children => children.map { |child| filterize(child) } })
  end
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
  fulltext = []
  fulltext << attribute[:display_name]
  fulltext << attribute[:name]
  fulltext << attribute[:description]
  attribute.merge!({ :id => rand(36**8).to_s(36), :text => attribute[:display_name] || attribute[:name], :fulltext => normalize(fulltext.compact.uniq.join(' ')), :qtipCfg => { :title => attribute[:display_name] || attribute[:name], :text => attribute[:description], :dismissDelay => 0 } })
  if children.empty?
    attribute.merge({ :leaf => true, :children => [], :iconCls => 'attribute-icon' })
  else
    attribute.merge({ :leaf => false, :children => children.map { |child| attributize(child) } })
  end
end

class MartSoap < Handsoap::Service

  def generate_static_json_files
    select_dataset_menu = { :text => 'BioMart', :iconCls => 'biomart-icon', :menu => [] }
    datasets = { :rows => [] }

    index = 0
    self.marts().each { |mart|
      if (!mart[:display_name] =~ /ensembl.*(genomic features|ontology|sequence)/i) || (mart[:display_name] =~ /reactome/i) || (mart[:display_name] =~ /ensembl/i) || (mart[:display_name] =~ /msd/i) || (mart[:display_name] =~ /pride/i) # to weed out stupid biomart.org marts
        mart_has_datasets = false
        mart_keywords = []
        KEYWORDS.each { |synset| synset.each { |keyword| mart_keywords << synset if mart[:display_name] =~ Regexp.new(keyword, true) } }
        case mart[:display_name]
        when /reactome/i
          mart_keywords << 'reactome'
        when /ensembl/i
          mart_keywords << 'ensembl'
        when /msd/i
          mart_keywords << 'msd'
          mart_keywords << 'proteins'
          mart_keywords << 'structures'
          mart_keywords << 'x-ray'
          mart_keywords << 'crystallography'
          mart_keywords << 'pdb'
        when /pride/i
          mart_keywords << 'pride'
          mart_keywords << 'peptides'
          mart_keywords << 'proteomics'
          mart_keywords << 'identifications'
          mart_keywords << 'proteins'
          mart_keywords << 'mass spectrography'
        end
        mart_keywords = mart_keywords.flatten.compact.uniq
        select_dataset_menu[:menu] << mart.merge({ :itemId => mart[:name],
                                                   :text => mart[:display_name] || mart[:name],
                                                   :iconCls => 'mart_icon',
                                                   :mart_name => mart[:name],
                                                   :mart_display_name => mart[:display_name] || mart[:name],
                                                   :menu => [] })
        mart_id = rand(36**8).to_s(36)
        datasets[:rows] << mart.merge({ :itemId => mart[:name],
                                        :text => mart[:display_name] || mart[:name],
                                        :iconCls => 'mart_icon',
                                        :mart_name => mart[:name],
                                        :mart_display_name => mart[:display_name] || mart[:name],
                                        :description => DESCRIPTION,
                                        :keywords => mart_keywords,
                                        :fulltext => normalize([mart[:display_name] || mart[:name], DESCRIPTION, mart_keywords].flatten.join(' ')),
                                        :_id => mart_id,
                                        :_parent => nil,
                                        :_is_leaf => false })
        self.datasets(mart[:name]).each { |dataset|
          if (dataset[:display_name] =~ /^[A-Z]/) || (mart[:display_name] =~ /reactome/i) # to weed out stupid biomart.org datasets
            print '.' # progress indicator
            mart_has_datasets = true
            dataset_keywords = []
            dataset_keywords.concat mart_keywords # inherit keywords from mart!
            KEYWORDS.each { |synset| synset.each { |keyword| dataset_keywords << synset if dataset[:display_name] =~ Regexp.new(keyword, true) } }
            dataset_keywords = dataset_keywords.flatten.compact.uniq
            select_dataset_menu[:menu][index][:menu] << dataset.merge({ :itemId => dataset[:name],
                                                                        :text => dataset[:display_name] || dataset[:name],
                                                                        :iconCls => 'dataset-icon',
                                                                        :mart_name => mart[:name],
                                                                        :mart_display_name => mart[:display_name] || mart[:name],
                                                                        :dataset_name => dataset[:name],
                                                                        :dataset_display_name => dataset[:display_name] || dataset[:name] })
            dataset_id = rand(36**8).to_s(36)
            datasets[:rows] << dataset.merge({ :itemId => dataset[:name],
                                               :text => dataset[:display_name] || dataset[:name],
                                               :iconCls => 'dataset-icon',
                                               :mart_name => mart[:name],
                                               :mart_display_name => mart[:display_name] || mart[:name],
                                               :dataset_name => dataset[:name],
                                               :dataset_display_name => dataset[:display_name] || dataset[:name],
                                               :description => DESCRIPTION,
                                               :keywords => dataset_keywords,
                                               :help_fields => [],
                                               :facet_fields => [],
                                               :fulltext => normalize([(dataset[:display_name] || dataset[:name]), (mart[:display_name] || mart[:name]), DESCRIPTION, dataset_keywords].flatten.join(' ')),
                                               :_id => dataset_id,
                                               :_parent => mart_id,
                                               :_is_leaf => true })

            # for each dataset write a static json files
            filename = "#{JSON_DIR}/#{mart[:name]}.#{dataset[:name]}.json"
            json = dataset.merge({ :itemId => dataset[:name],
                                   :text => dataset[:display_name] || dataset[:name],
                                   :iconCls => 'dataset-icon',
                                   :mart_name => mart[:name],
                                   :mart_display_name => mart[:display_name] || mart[:name],
                                   :dataset_name => dataset[:name],
                                   :dataset_display_name => dataset[:display_name] || dataset[:name],
                                   :description => DESCRIPTION,
                                   :keywords => dataset_keywords,
                                   :help_fields => [],
                                   :facet_fields => [],
                                   :filters => self.filters(dataset[:name]).map { |filter| filterize(filter) },
                                   :attributes => self.attributes(dataset[:name]).map { |attribute| attributize(attribute) } }).to_json
            File.open(filename, 'w') { |f| f.write(json) }
          end
        }
        # make 100% sure that mart has datasets because ui is tripped by empty marts
        if mart_has_datasets
          index =+ 1
        else
          select_dataset_menu[:menu].pop
          datasets[:rows].pop
        end
      end
      # break if index > 0
    }

    # write select_dataset_menu static json file
    filename = "#{JSON_DIR}/select_dataset_menu.json"
    json = select_dataset_menu.to_json
    File.open(filename, 'w') { |f| f.write(json) }


    # sort datasets
    datasets[:rows] = datasets[:rows].sort_by { |row| row[:dataset_display_name] || row[:mart_display_name] }
    # write datasets static json file
    filename = "#{JSON_DIR}/datasets.json"
    json = datasets.to_json
    File.open(filename, 'w') { |f| f.write(json) }

    print ". done!\n" # progress indicator
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

  def ns; { 'ns' => "http://www.biomart.org:80/MartServiceSoap" }; end

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
      :default => xml_to_bool(node, './ns:default/text()') || false,
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
      :filters => node.xpath('./ns:filterInfo', ns).map { |node| parse_filter(node) }
    }
  end

  def parse_filter(node)
    {
      :name => xml_to_str(node, './ns:name/text()'),
      :display_name => xml_to_str(node, './ns:displayName/text()'),
      :default => xml_to_bool(node, './ns:default/text()') || false,
      :description => xml_to_str(node, './ns:description/text()'),
      :model_reference => xml_to_str(node, './ns:modelReference/text()'),
      :qualifier => xml_to_str(node, './ns:qualifier/text()'),
      :options => xml_to_str(node, './ns:options/text()'),
    }
  end

end
