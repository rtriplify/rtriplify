require  'configatron'

class TriplifyController < ActionController::Base
  def all
    #get all models
    #render all models
    ret=""
    t = Tripleizer.new
    $base_uri= t.uri request.env['REQUEST_URI'].to_s

    filename = 'test.rdf'
    headers.merge!(
      'Content-Type' => 'text/rdf+n3',
      'Content-Disposition' => "attachment; filename=\"#{filename}\"",
      'Content-Transfer-Encoding' => 'binary'
    )

    t.output_json = request.content_type.try(:to_sym)==:json
    content_type =   t.output_json   ? 'application/json' :  'text/plain'
    render :content_type => content_type , :text => proc { |response, output|
      t.output = output
      t.write_rdf_head
      model_groups =  eval("configatron.query").to_hash
      model_groups.each do |model_group_name,model_group|
        model_group.each do |model_name,model_attributes|
          if model_name.to_s =="sql_query"
            t.write_sql(model_group_name,model_attributes)
          else
            t.write_model(model_name, model_attributes)
          end
        end
      end
      t_metadata = TriplifyMetadata.new      
      t_metadata.write_metadata(t)
      output.write t.json if  t.output_json
    }

  end

  def model
    ret=""
    t = Tripleizer.new
    $base_uri= t.uri request.env['REQUEST_URI'].to_s.split(params[:model])[0]
    render :content_type => 'text/plain', :text => proc {|response, output|
      t.write_rdf_head(output)
      model_group= params[:model].to_s #TODO:groß/kleinschreibung.capitalize
      model_group.downcase!
      params[:id] ? entries= [params[:id]] : entries = :all
      #TODO: multiple models
      models = t.search_models model_group
      models.each do |model_name, model_attributes|
        if model_name.to_s =="sql_query"
          t.write_sql(model_group_name,model_attributes,output)
        else
          t.write_model(model_name, model_attributes, output)
        end
      end
      #write metadata
      #t.write_rdf_metadata(t,output)
    }
  end

  def index
    ret=""
    t = Tripleizer.new
    $base_uri= t.uri request.env['REQUEST_URI'].to_s
    render :content_type => 'text/plain', :text => proc { |response, output|
      t.write_rdf_head(output)
      subclass = $base_uri.split("triplify/")[1].split("/")

      group = eval("configatron.query."+controller).to_hash;
      group.each do |key,name|
        model = key.to_s.capitalize
        model = eval(model)
        dtypes =t.dbd_types model

        model= model.find(:all)
        mapping =eval("configatron.query."+controller+"."+key.to_s).to_hash

        model.each do |item|
          #t.write_triple(item.id, object, is_literal, dtype, lang)
          c1 = Hash.new
          #add first the id
          c1[:id] = item.id
          #und jetzt das mapping
          mapping.each do |k,v|
            c1[k]=eval("item."+v.to_s)
          end

          output.write t.make_triples(c1, controller , "", dtypes)
          #render :text =>  t.make_triples(c1, controller , "", t.dbd_types)
        end
      end
      meta = TriplifyMetadata.new
      t.output=output
      meta.write_metadata t,output
    }
  end
end
