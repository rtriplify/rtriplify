require 'tripleizer'
require 'configatron'

class TriplifyMetadata
def write_metadata tripleizer,output
    p = ProvenanceWriter.new
    p.describe_provenance "",tripleizer,output
  end
end

class ProvenanceWriter
  def initialize

  end

  def describe_provenance( subject, tripleizer,output)
    @now = Time.new
    @triplify_instance = get_new_bnode_id
    tripleizer.write_triple(subject, tripleizer.uri("rdf:type" ), tripleizer.uri("prv:DataItem" ))

    if configatron.data_set
      tripleizer.write_triple( subject, tripleizer.uri("prv:containedBy"),tripleizer.uri(configatron.data_set ))
			tripleizer.write_triple( tripleizer.uri(configatron.data_set), tripleizer.uri('rdf:type'), tripleizer.uri('void:Dataset') )
    end

    creation = get_new_bnode_id
    tripleizer.write_triple( subject, tripleizer.uri("prv:createdBy"), creation )
		describe_creation( creation, tripleizer )
		describe_triplify_instance( @triplify_instance, tripleizer );
  end

  def describe_triplify_instance(subject, tripleizer)
    tripleizer.write_triple(subject,tripleizer.uri("rdf:type"),tripleizer.uri("prvTypes:DataCreatingService"))
    tripleizer.write_triple(subject,tripleizer.uri("rdfs:comment"), "Triplify #{tripleizer.version} (http://Triplify.org)", "isliteral")

    operator=""
    if configatron.operator_uri
      operator = tripleizer.uri(configatron.operator_name)
    else
      if configatron.operator_type || configatron.operator_homepage
        operator= get_new_bnode_id
      end
    end

    unless operator.blank?
      tripleizer.write_triple( subject, tripleizer.uri('prv:operatedBy'), operator )
			if configatron.operator_type
				if (  tripleizer.uri(configatron.operator_type) != tripleizer.uri('prv:HumanActor') )
          tripleizer.write_triple(operator, tripleizer.uri('rdf:type'),tripleizer.uri(configatron.operator_type) )
        end
      end
			tripleizer.write_triple(operator, tripleizer.uri('rdf:type'),tripleizer.uri('prv:HumanActor') )
			if configatron.operator_name
        tripleizer.write_triple( operator, tripleizer.uri('foaf:name'), configatron.operator_name, "true" )
      end
			if  configatron.operator_homepage
        tripleizer.write_triple( operator, tripleizer.uri('foaf:homepage'), configatron.operator_homepage )
      end
    end
  end

  def describe_creation(subject, tripleizer)
    tripleizer.write_triple( subject, tripleizer.uri('rdf:type'), tripleizer.uri('prv:DataCreation') )
    #TODO: @now in iso time format date("c",...
    tripleizer.write_triple( subject, tripleizer.uri('prv:performedAt'),@now , "true", tripleizer.uri('xsd:dateTime') )

		creator = @triplify_instance
		source_data = get_new_bnode_id

		mapping =  configatron.mapping ? tripleizer.uri(configatron.mapping) : get_new_bnode_id

    tripleizer.write_triple( subject, tripleizer.uri('prv:performedBy'), creator );
    tripleizer.write_triple( subject, tripleizer.uri('prv:usedData'), source_data );
    tripleizer.write_triple( subject, tripleizer.uri('prv:usedGuideline'), mapping );

		describe_source_data( source_data, tripleizer );
		describe_mapping( mapping, tripleizer );
  end

  def describe_source_data ( subject, tripleizer )
		doc = get_new_bnode_id
		tripleizer.write_triple( subject,  tripleizer.uri('prv:containedBy'), doc )
		tripleizer.write_triple( doc,  tripleizer.uri('rdf:type'),  tripleizer.uri('prv:Representation') )

		access = get_new_bnode_id
		tripleizer.write_triple( doc,  tripleizer.uri('prv:retrievedBy'), access )
		describe_source_data_access access, tripleizer
  end

  def describe_source_data_access ( subject, tripleizer )
		tripleizer.write_triple( subject,
      tripleizer.uri('rdf:type'),
      tripleizer.uri('prv:DataAccess') )
		tripleizer.write_triple( subject,
      tripleizer.uri('prv:performedAt'),
      @now,
      "true",
      tripleizer.uri('xsd:dateTime') )

		if configatron.database_server
			tripleizer.write_triple( subject,
        tripleizer.uri('prv:accessedServer'),
        tripleizer.uri(configatron.database_server) )
    end
		accessor = @triplify_instance
		tripleizer.write_triple( subject,  tripleizer.uri('prv:performedBy'), accessor )
  end


	def describe_mapping ( subject, tripleizer )
		tripleizer.write_triple( subject,  tripleizer.uri('rdf:type'),  tripleizer.uri('prvTypes:TriplifyMapping') )
  end

	def get_new_bnode_id ()
    @bnode_counter ||=0
		@bnode_counter+=1
		"_:x#{@bnode_counter}"
  end

end
