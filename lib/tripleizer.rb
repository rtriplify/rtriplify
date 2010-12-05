require 'configatron'
require 'json'

# This is the core class of triplify
# Use instance of this class to get your defined RDF data


# Author::    Nico Patitz  (mailto:nico.patitz@gmx.de)
# Copyright:: Copyright (c) 2010 Nico Patitz
# License::   Distributes under the same terms as triplify


class Tripleizer
  # build new instance
  # define you can define output param
  def initialize output=nil
    @object_properties = configatron.objectProperties.to_hash
    @object_namespaces = configatron.namespaces.to_hash
    @class_map = configatron.classMap.to_hash
    @output=output
    @version="0.0.2"
    @json_hash = Hash.new
    @output_json = nil;
    @base_uri = "http://example.com/"
  end
  
  # stores RDF output as string
  attr_accessor :output
  # rtriplify-version showed in RDF
  attr_reader :version
  # the RDF data as a json object
  attr_accessor :output_json
  # base uri..if not set, std. from config is used
  attr_accessor :base_uri

  #Generation of N3 RDF with iterative depth
  def rdf rdf_start_class , var=[]
    class_map = Hash.new
    var.each do  |c|
      class_map[c[0].class.to_s]= c
    end
    rdf_string =""
    #get configuration start ->classes
    m = find_models(rdf_start_class)
    if m
      m.values[0].each do |mod,attributes|
        unless mod.eql?("sql_query")
          t_mod = Model.new(mod, rdf_start_class, class_map[mod.to_s])
          #if sql...
          key = t_mod.get_key
          t_mod.get_rows.each do |item|
            rdf_string<<rdf_by_id(mod,rdf_start_class,eval("item.#{key}"))
          end
        end
      end
    end
    rdf_string
  end

  # get a RDF node by its ID and resource-class.
  # Iterative Function, so be carefull with your config not to produce endless loops
  def rdf_by_id model_name, class_name, id
    puts model_name
    ret=""
    #TODO...mehrere Models

    model = Model.new(model_name,class_name)   
    data_types= model.get_datatypes
    #build hash
    item=model.get_row_by_id(id).first
    line = Hash.new
    subline = Hash.new
    remove =Array.new

    model.model_attributes.each do |k,v|
      if v.to_s.include?("*") || v.to_s[0..9]=="new_model("
        remove.push(k.to_s) unless remove.index(k.to_s)
        m_class,field=v.to_s.split("*")
        ref_pred,ref_model=k.to_s.split"->"
        if  v.to_s[0..5]=="MODEL("
          m_class.gsub!("MODEL(","Model.new(")
          submodel= eval(m_class.to_s)
          sub_rows= submodel.get_rows
        else
          submodel= eval("item.#{m_class.to_s.downcase}")
          sub_rows= submodel
        end
        sub_rows.each do |subitem|          
          sub_id=eval("subitem.#{field}")  
          ret<< make_triples({:id=>id,k=>sub_id  },class_name,"",Array.new,false)
          ret<<rdf_by_id( submodel.model_name ? submodel.model_name : m_class , ref_model,sub_id).to_s
        end
      else    
        write_line = true;
        #FIXME: use last "." split
        if k.to_s.include? "->"
          line[k.to_s]=eval("item."+v.to_s)
          #write key ref 
          ref_pred,ref_model=k.to_s.split"->"   
          #write referenced model
          #ret<< make_triples({:id=>id,k=>sub_id  },class_name,"",Array.new,false)
          m= find_models(ref_model)
          m.values[0].each do |mod,val|
            ret<<(rdf_by_id mod, ref_model, eval("item."+v.to_s)).to_s
          end
        else        
          if v.to_s.include? "."
            write_line = nil unless eval("item."+v.to_s.downcase.split(".")[0])
          end
          begin
            if v.to_s[0..5]=="CONST("
              line[k.to_s],data_types[k.to_s]= model.get_const(v)
              #datatype to uri format
              if data_types[k.to_s]=="LINK"
                line[k.to_s] =uri line[k.to_s]
                data_types.delete k.to_s
                @object_properties[k.to_s]="t"
              else
                data_types[k.to_s] = uri(data_types[k.to_s])
              end
            else
              line[k.to_s]=eval("item."+v.to_s) if write_line

            end
          rescue Exception => ex
            line[k.to_s]=v.to_s if write_line
          end
        end
      end
      # end
    end
    extract_id_line(model.model_attributes, line, item,data_types)
    remove.each { |rem_attrib|  line.delete(rem_attrib) }
    #get triples of row
    ret<<make_triples(line, class_name , "", data_types)   
    ret
  end

  # rdfa generation
  # iterative and returns "hidden" rdfa-div-tags
  def rdfa rdf_start_class , var=[]
    #write namespace
    "<div #{@object_namespaces.collect {|pre,ns| "xmlns:"<<pre.to_s<<"=\""<<ns.to_s<<"\" " }}>\n #{rdfa_root(rdf_start_class,var)} </div>"
  end

  # the root rdf node
  def rdfa_root rdf_start_class , var=[]
    #map each var on its classname
    rdfa_string = ""
    class_map = Hash.new
    var.each do  |c|
      class_map[c[0].class.to_s]= c
    end

    #get configuration start ->classes
    m = find_models(rdf_start_class,true)
    if m
      m.values[0].each do |mod,attributes|
        unless mod.eql?("sql_query")
          t_mod = Model.new(mod, rdf_start_class, class_map[mod.to_s])
          #if sql...
          key = t_mod.get_key
          t_mod.get_rows.each do |item|
            rdfa_string<<find_rdfa_by_id(rdf_start_class,eval("item.#{key}"))
          end
        end
      end
    end
    rdfa_string
  end

  # generate RDFa tags by a specified ID
  def find_rdfa_by_id rdf_start_class , id
    #map each var on its classname
    id = id.to_s
    rdfa_string = "<div  about=\"#{rdf_start_class+"/"<<id}\" typeof=\"#{@class_map[rdf_start_class.to_sym]}\">\n"
    #get configuration start ->classes
    m = find_models(rdf_start_class,true)
    if m
      m.values[0].each do |mod,attributes|
        unless mod.to_s.eql?("sql_query")
          t_mod = Model.new(mod, rdf_start_class)
          #if sql...
          item=t_mod.get_row_by_id(id).first
          t_mod.model_attributes.each do |name,link_field|
            #property
            #link to other ress
            if name.to_s.include? "->"
              m_class,role_mod = name.to_s.split "->"

              if role_mod.eql?("sql_query")
                hello=""
              else
                if link_field.include?("*")
                  field_class,field= link_field.to_s.split("*")
                  if field_class.to_s[0..5]=="MODEL("
                    field_class.gsub!("MODEL(","Model.new(")
                    submodel= eval(field_class.to_s).get_rows
                    rdfa_string<<"<div rel=\"#{m_class}\">\n"
                    submodel.each do |line|
                      rdfa_string<<find_rdfa_by_id(role_mod , eval("line.#{field.to_s}"))
                    end
                    rdfa_string<<"</div>\n"
                  else
                    subitem =  eval("item.#{field_class}")
                    rdfa_string<<"<div rel=\"#{m_class}\">\n"
                    subitem.each do |subline|
                      rdfa_string<<  find_rdfa_by_id(role_mod , eval("subline.#{field.to_s}"))
                    end
                    rdfa_string<<"</div>\n"
                  end
                else
                  rdfa_string<<"<div rel=\"#{m_class}\">\n"
                  rdfa_string << find_rdfa_by_id(role_mod , eval("item.#{link_field.to_s}"))
                  rdfa_string<<"</div>\n"
                end
              end
            else
              write=true
              #just a property
              #CONST(
              #Model(
              if link_field.to_s[0..5] =="CONST("
                write=false
                val,data_type= t_mod.get_const(link_field)
                if data_type=="LINK"
                  #link
                  rdfa_string<<"<div rel= \"#{name}\" resource=\"#{val}\"> </div>\n"
                else
                  #value
                  rdfa_string<<"<div property= \"#{name}\"  content=\"#{val}\" datatype=\"#{data_type}\"> </div>\n"
                end
              else
                m_class,field= link_field.to_s.split("*")
                if  name.to_s[0..5]=="MODEL("
                  m_class.gsub!("MODEL(","Model.new(")
                  submodel= eval(m_class.to_s).get_rows
                  submodel.each do |line|
                    datatype="string"
                    rdfa_string<<"<div property= \"#{ref_pred}\"  content=\"#{eval("line.#{field.to_s.downcase}")}\" datatype=\"#{data_type}\"> </div>\n"
                  end
                end
                if field
                  write = false
                  #rdfa_string<<find_rdfa_by_id("","")
                end
              end
              rdfa_string<<"<div property= \"#{name}\"  content=\"#{eval("item.#{link_field}")}\"></div>\n" if write
            end
          end
        end
      end
    end
    rdfa_string << "</div>\n"
  end

  #not used
  def tripleize (tr_self,c =nil,id=nil)
  end

  # Find all the models to the given key ( the RDF-Class name)
  # returns a hash with the RDF-Class name as key and the models as value
  # rdfa -> if true, watch for a RDFa section
  def find_models key, rdfa=nil
    if rdfa
      model_groups =  eval("configatron.rdfa_query") ?  eval("configatron.rdfa_query").to_hash : eval("configatron.query").to_hash    
    else
      model_groups =  eval("configatron.query").to_hash
    end  
    model_groups.each do |model_group_name,model_group|
      if model_group_name.to_s.downcase == key.downcase
        return {model_group_name=>model_group}
      end
    end
    nil
  end

  # write the model(s) depending on its RDF-Class name.
  # This is one of the core funktions of rtriplify
  def write_model model_name, class_name
    puts model_name
    ret=""
    model = Model.new(model_name,class_name)   
    data_types= model.get_datatypes
    #build hash
    model.get_rows.each do |item|
      line = Hash.new
      subline = Hash.new
      #and now add all mapping-attributes
      remove =Array.new
      model.model_attributes.each do |k,v|
        #        if k.to_s.include?("->")
        if v.to_s.include?("*") || v.to_s[0..9]=="new_model("

          remove.push(k.to_s) unless remove.index(k.to_s)
          m_class,field=v.to_s.split("*")
          ref_pred,ref_model=k.to_s.split"->"
          if  v.to_s[0..5]=="MODEL("
            m_class.gsub!("MODEL(","Model.new(")
            submodel= eval(m_class.to_s).get_rows
          else
            submodel= eval("item.#{m_class.to_s.downcase}")
          end
          submodel.each do |subitem|
            subline[:id] = eval("item.#{model.get_key}")
            subline[k] = eval("subitem.#{field}")
            #extract_id_line(m.model_attributes, subline, subitem, Array.new)
            ret<<make_triples(subline, class_name, false,Array.new,false )
            subline.clear
          end
        else
          write_line = true;
          if v.to_s.include? "."
            write_line = nil unless eval("item."+v.to_s.downcase.split(".")[0])
          end
          begin
            if v.to_s[0..5]=="CONST("
              line[k.to_s],data_types[k.to_s]= model.get_const(v)
              #datatype to uri format
              if data_types[k.to_s]=="LINK"
                line[k.to_s] =uri line[k.to_s]
                data_types.delete k.to_s
                @object_properties[k.to_s]="t"
              else
                data_types[k.to_s] = uri(data_types[k.to_s])
              end
            else
              line[k.to_s]=eval("item."+v.to_s) if write_line
            end
          rescue Exception => ex
            line[k.to_s]=v.to_s if write_line
          end
        end
        # end
      end
      extract_id_line(model.model_attributes, line, item,data_types)
      remove.each { |rem_attrib|  line.delete(rem_attrib) }
      #get triples of row
      ret<<make_triples(line, class_name , "", data_types)
      #render :text =>  t.make_triples(c1, controller , "", t.dbd_types)
    end
    ret
  end

  # search for the ID field and set it in line var- to the "id"-key
  def extract_id_line model_attributes, line,item,dtypes
    #look if id is mapped to another field
    id_keys = model_attributes.to_hash.keys
    #hotfix..bad performance
    id_keys.map!{|k| k.to_s }
    id_key= id_keys.select{|k| k =~/^(ID|id|iD|Id)$/ }
    if id_key.empty?
      line[:id] = item.id
    else
      line[:id] = eval("item.#{model_attributes[id_key[0].to_sym]}")
      #set the correct datatype for it
      dtypes["id"]= dtypes[id_key[0]]
      #remove the id line
      line.delete id_key[0]
    end
  end

  # Executes a sql command. Better to not use this function
  def write_sql model_name, model_attributes,output
    model_attributes.each do|key,query|
      sql=  ActiveRecord::Base.connection();
      (sql.select_all query).each do |row|
        make_triples(row,model_name,"")
      end
    end
  end

  # the standard triples at the beginning of your rdf output ( version and licence)
  def write_rdf_head
    # $this->writeTriple($self,$this->uri('rdfs:comment'),'Generated by Triplify '.$this->version.' (http://Triplify.org)',true);
    write_triple(@base_uri, uri("rdfs:comment"), 'Generated by Triplify '+'version'+ "  (http://Triplify.org) ", "literal" )
    unless configatron.license.blank?
      #$this->writeTriple($self,'http://creativecommons.org/ns#license',$this->config['license']);
      write_triple(@base_uri,'http://creativecommons.org/ns#license',configatron.license, "literal" )
    end
  end

  # generate the triples from a given hash  
  def make_triples (c1,rdf_class,maketype,dtypes=Array.new,rdf_type=true)
    rdf_ns="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    ipref= uri rdf_class.to_s+'/'
    is_literal=false
    dtype,lang,ret="","",""
    object_property = nil
    triples =""

    unless c1[:id]
      id_row = c1.select {|k,v| k =~ /^(id|ID|iD|Id)$/}
      c1[:id] = id_row[0][1]
      c1.delete id_row[0][0]

      #set datatype for id
      #dtypes[:id] = uri( (id_row[0][1]).type)
    end

    subject = uri c1[:id].to_s,ipref
    #write model :-)

    c= @class_map[rdf_class.to_sym] ?@class_map[rdf_class.to_sym]:rdf_class
    triples << write_triple(subject, rdf_ns+"type", uri(c, @object_namespaces[:vocabulary]))  if rdf_type
    # write_triple(subject,predi    cate,object                                                  ,is_literal=false,dtype="",lang="",json=nil)
    c1.delete :id unless rdf_type

    c1.each do |k,v|
      #FIXME: not quite satisfied with this source part
      dtype=""
      k=k.to_s
      if v.to_s.empty?
        next
      end

      # beinhaltet key ^^ dann type oder sprache richtig setzen
      if k.index("^^")
        #TODO: k,dtype = k.split("^^")
        dtype= uri k.split("^^")[1]
        k= k.split("^^")[0]
      else if dtypes.include? k
          dtype= uri dtypes[k]
        else if k.index("@")
            lang=k.split("@")[1]
            k = k.split("@")[0]
          end
        end
      end
      # 
      if k.index("->")
        k, object_property = k.split("->")
      else
        object_property = @object_properties[k]
      end

      #TODO
      #callbackfunktion
      #

      prop= self.uri(k,@object_namespaces[:vocabulary])
      unless object_property
        is_literal= true
        object= v.to_s
      else
        is_literal= false      
        #TODO: fixme "/" in the middle      
        object= uri  "#{object_property}#{object_property[-1,1].to_s !="/" ? "/":":"}#{v}"
        if object[0..1] == "t/"
          object = object.to_s[2..-1]
        end
      end
      triples<<write_triple(subject,prop,object,is_literal,dtype,lang).to_s
    end
    triples
  end

  # triple will be given to its defined output (json||inner_variable||return value
  def write_triple(subject,predicate,object,is_literal=false,dtype="",lang="")
    if @output_json
      oa = {:value=> object,:type=> is_literal ? 'literal' : 'uri'}
      oa['datatype']=dtype if is_literal && dtype
      oa['language']=lang if is_literal && lang
      add_json_pair subject, predicate,oa
      return ""
    else
      #(lang?"@#{lang}":'')
      #define the object
      if(is_literal)
        object = "\"#{object.to_s.gsub('"','%22')}\""+  (dtype.empty? ?  (lang.empty? ? "": "@#{lang}" ):"^^<#{dtype}>" )
      else
        object = ( object[0..1] == "_:" ) ? object : "<#{object}>"
      end
      #object="\"#{object[1..-2].gsub('"','\"')}\""
      #define the subject
      subject = ( subject[0..1] == "_:" ) ? subject : "<#{subject}>"
      if @output
        @output.write "#{subject} <#{predicate}> #{object} .\n"
      end
      return "#{subject} <#{predicate}> #{object} .\n"
    end
  end

  #generates an uri with the given name
  def uri (name,default="")
    
    name=name.to_s
    #FIXME: bad urls (for example just www.example.com will produce an endless-loop
    if name.try(:include?, "://")
      return name[0..name.length-2] if name[-1,1]=="/"
      return name[0..name.length]
    else
      name +="/" unless (name[name.length-1..name.length-1] == ("/" || "#")) || name.try(:include?, ":")

      if name.index(":")    
        t= @object_namespaces[name.split(":")[0].to_sym]
        t ||=""
        t += "/" unless (t[t.length-1..t.length-1] == ("/" || "#") || t.blank?) || name.try(:include?, ":")
        return  uri( t+ normalize_local_name(name.split(":")[1])+"/")
      else     
        t=  default.blank? ?  @base_uri   : default
        t += "/" unless t[t.length-1..t.length-1]=="/"
        return  uri( t + normalize_local_name(name))
      end
    end
  end

  # extract the base uri for triple generation from given request
  # if param "set" is true, the inner base_uri variable off class will be set too
  def generate_base_uri request, set=nil
    b_uri= uri request.env['REQUEST_URI'].to_s[0..-request.env['PATH_INFO'].length]
    @base_uri = b_uri if set
    b_uri
  end

  # returns an hash with columnname as key and datatype as value
  def dbd_types (model,model_attributes)
    #hard coded mapping look mapping table
    mapping = Hash[ "binary"=>"base64Binary","boolean"=>"boolean","date"=>"date","datetime"=>"dateTime","decimal"=>"decimal","float"=>"float","integer"=>"integer","string"=>"string","text"=>"string","time"=>"time","timestamp"=>"dateTime",]
    dtypes = Hash.new
    model.columns_hash.each_key do |m|
      #make xsd datatye
      dtypes[m.to_s] ="xsd:#{mapping[model.columns_hash[m].type.to_s] }"
    end
    #replace mapping
    model_attributes.each do |k,v|
      dtypes[k.to_s]=dtypes[v.to_s]
    end
    dtypes
  end
  #some encoding stuff
  def normalize_local_name name
    CGI::escape(name).gsub(/%2F/,'/').gsub(/%23/,'#') 
  end

  # if output var is set to jason, you get the json source here
  def json
    @json_hash.to_json
  end

  # adds a pair to the json hash tree
  def add_json_pair subject, predicate,oa
    if @json_hash.key? subject
      if @json_hash[subject].key? predicate
        @json_hash[subject][predicate].merge!(oa)
      else
        @json_hash[subject][predicate]=oa
      end
    else
      @json_hash[subject]=Hash.new
      @json_hash[subject][predicate]=oa
      hello="test"
    end
  end
end
