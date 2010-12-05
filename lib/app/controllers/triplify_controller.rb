require  'configatron'
#
class TriplifyController < ActionController::Base

  def tripleize
    t = Tripleizer.new
    t.base_uri = t.uri request.env['REQUEST_URI'].to_s
    depth = configatron.linked_data_depth.to_i

    filename = 'data.n3'
    headers.merge!(
      'Content-Type' => 'text/rdf+n3',
      'Content-Disposition' => "attachment; filename=\"#{filename}\"",
      'Content-Transfer-Encoding' => 'binary'
    )

    t.output_json = request.content_type.try(:to_sym)==:json
    content_type =   t.output_json   ? 'application/json' :  'text/plain'

    render :content_type => content_type , :text => proc { |response, output|
      t.output = output      
      case params[:specs].length
      when 0
        t.write_rdf_head
        all t if depth > -1
      when 1
        t.base_uri = t.base_uri.to_s[0..t.base_uri.to_s.index(params[:specs][0].to_s)-1]
        t.write_rdf_head
        model t, params[:specs][0] if depth >0
      when 2
        t.base_uri = t.base_uri.to_s[0..t.base_uri.to_s.index(params[:specs][0].to_s)-1]
        t.write_rdf_head
        index t, params[:specs] if depth > 1
      end
      
      t_metadata = TriplifyMetadata.new
      t_metadata.write_metadata(t)
      output.write t.json if t.output_json
    }
  end

  private
  
  def all t
    #get all models
    #render all models
    ret=""
    model_groups =  eval("configatron.query").to_hash
    model_groups.each do |model_group_name,model_group|
      model_group.each do |model_name,model_attributes|
        if model_name.to_s =="sql_query"
          t.write_sql(model_group_name,model_attributes,t.output)
        else
          t.write_model(model_name,model_group_name)
        end
      end
    end
    ""
  end

  #get all models
  def model t, model_group   
    models = t.find_models model_group
    if models
      models.values[0].each do |model_name, model_attributes|
        if model_name.to_s =="sql_query"
          t.write_sql(models.keys[0],model_attributes,output)
        else
          t.write_model(model_name, models.keys[0])
        end
      end
    end
  end

  # get a defined model with given id
  def index t,param
    subclass,id = param
    models = t.find_models subclass
    if models
      models.values[0].each do |model_name, model_attributes|
        if model_name.to_s =="sql_query"
          #some magic is needed here  ..parse the sql query?
        else
          m = Model.new model_name,  models.keys[0].to_s
          row_values=m.get_row_by_id(id).first
          c1=Hash.new
          if row_values
            m.model.columns_hash.each_with_index do |column_name,i|
              c1[column_name[0]]=eval("row_values.#{column_name}")
            end
            t.extract_id_line model_attributes, c1,row_values,m.get_datatypes
            t.make_triples(c1,  models.keys[0].to_s , "", m.get_datatypes)
          end
        end
      end
    end
    #render :text =>  t.make_triples(c1, controller , "", t.dbd_types)
    
  end
end
