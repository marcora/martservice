require 'solr'

class MartSolr

  @@conn = Solr::Connection.new('http://localhost:8983/solr')

  def self.search(q)
    rows = []
    columns = []
    fields = []
    count = 0
    last_doc = nil
    @@conn.query(q, :rows => 100).each { |doc|
      rows << doc
      last_doc = doc
      count += 1
    }
    if last_doc
      keys = last_doc.keys()
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
    end
    return { :columns => columns, :fields => fields, :rows => rows, :count => count }
  end
end
