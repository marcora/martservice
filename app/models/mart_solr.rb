require 'delsolr'

class MartSolr

  @@conn = DelSolr::Client.new(:server => 'localhost', :port => 8983)

  def self.search(q, facet_fields=[], filters=[])
    solr_fields = ['pdb_id','title','header','experiment_type','resolution','keywords_concat','space_group','r_work','authors','submission_date','release_date']
    columns = []
    fields = []
    facets = []
    response = @@conn.query('standard', :query => q, :limit => 100, :fields => solr_fields.join(',') , :facets => facet_fields.map { |facet_field| { :field => facet_field, :mincount => 1, :sort => true } }, :filters => filters)
    facet_fields_hash = response.facet_fields_by_hash
    filters_hash = { }
    filters.each { |filter|
      key = filter.split(':')[0]
      value = filter.split(':')[1]
      if value =~ /^["].*\s+.*["]$/i
        value = value[1...value.length-1]
      end
      filters_hash[key] = value
    }
    ms = MartSoap.new
    ms.attributes('msd').each { |root|
      root[:groups].each { |group|
        group[:collections].each { |collection|
          collection[:attributes].each { |attribute|
            if solr_fields.include? attribute[:name]
              columns << { :header => attribute[:display_name] || attribute[:name], :width => 100, :id => attribute[:name] }
              fields << { :name => attribute[:name] }
              if filters_hash.keys.include? attribute[:name]
                facet_fields_hash.delete(attribute[:name])
                facets << {
                  :xtype => 'facetfield',
                  :anchor => '100%',
                  :name => attribute[:name],
                  :fieldLabel => attribute[:display_name] || attribute[:name],
                  :value => filters_hash[attribute[:name]]
                }
              end
              if facet_fields_hash.keys.include? attribute[:name]
                store = []
                facet_fields_hash[attribute[:name]].each { |val, count| store << [val, "#{val} [#{count}]"] }
                facets << {
                  :xtype => 'combo',
                  :anchor => '100%',
                  :name => attribute[:name],
                  :fieldLabel => attribute[:display_name] || attribute[:name],
                  :editable => false,
                  :forceSelection => true,
                  :lastSearchTerm => false,
                  :triggerAction => 'all',
                  :mode => 'local',
                  :store => store
                }
              end
            end
          }
        }
      }
    }
    return { :columns => columns, :fields => fields, :facets => facets, :rows => response.docs, :count => response.total }
  end
end
