# To change this template, choose Tools | Templates
# and open the template in the editor.
require 'configatron'

class Model
  attr_accessor :model
  attr_accessor :model_name 
  attr_accessor :model_attributes
  attr_accessor :model_class

  #hard coded mapping look mapping table
  @mapping


  def initialize model_name, model_class, var=nil
    @model_name= model_name
    @model_class= model_class
    #read the model attributes
    @model_attributes = get_model_attributes model_name,model_class
    @model = var ? var : get_model
    @mapping = Hash[ "binary"=>"base64Binary","boolean"=>"boolean","date"=>"date","datetime"=>"dateTime","decimal"=>"decimal","float"=>"float","integer"=>"integer","string"=>"string","text"=>"string","time"=>"time","timestamp"=>"dateTime",]
  end

  
  def get_model
    eval(@model_name.to_s)
  end 

  def get_const input
    #remove function name
    input = input.to_s
    input = input[6..input.index(')')-1]

    const = input.index(",")? input.split(",")[0]:input
    datatype = input.index(",")? input.split(",")[1]: "xsd:String"
    return [const,datatype]
  end

  ###
  # *returns the filter of the model
  #*@remove if filter should be removed from model_attributes list
  ##*/
  def get_filter remove=false
    filter=nil
    if model_attributes.has_key? :filter
      filter=""
      model_attributes[:filter].to_hash.each do |a,b|
        filter += (filter.blank? ? "" : " and ") +  a.to_s.downcase+b.to_s
      end      
      model_attributes.delete :filter if remove
    end
    filter
  end

  def get_include
    ret = Array.new
    #    model_attributes.select {|k,v| k.to_s.include?("->")}.each do |attribute|
    #      ref_model = attribute[0].to_s.split("->")[1]
    #      get_model_model(@model_class).each do |r_mod|
    #        ret.push(r_mod.to_s.capitalize.to_sym)
    #      end
    #    end

    model_attributes.select {|k,v| v.to_s.include?("*")}.each do |attribute|
      m_class,field=attribute[1].to_s.split("*")
      #get model
      ret.push(m_class.downcase.to_sym) unless ret.index(m_class.downcase.to_sym) || m_class[0..5]=="MODEL("
    end

    model_attributes.select {|k,v| v.to_s.include?(".")}.each do |attribute|
      ref_model = attribute[1].split(".")[0].to_s.downcase
      #get model
      ret.push(ref_model.to_sym) unless ret.index(ref_model.to_sym)
    end
    ret
  end

  def get_model_attributes key, model_class
    model_groups =  eval("configatron.query").to_hash
    model_groups.each do |model_group_name,model_group|
      if model_group_name.to_s==model_class.to_s
        hello="hello"
        model_group.each do |model_name_query,attributes|
          return attributes if model_name_query.to_s.downcase == key.to_s.downcase
        end
      end
    end
    nil
  end

  def get_model_model model_class
    model_groups =  eval("configatron.query").to_hash
    model_groups.each do |model_group_name,model_group|
      if model_group_name==model_class
        return model_group.keys
      end
    end
    nil
  end

  def read_attributes
    get_model_attributes @model_name
  end
  
  def get_datatypes   
    dtypes = Hash.new
    @model.columns_hash.each_key do |m|
      #make xsd datatye
      dtypes[m.to_s] ="xsd:#{@mapping[@model.columns_hash[m].type.to_s] }"
    end
    #replace mapping
    @model_attributes.each do |k,v|
      if ((v.include? "*") ||(v.include? "." )) && v.to_s[0..5]!="Model("
        field,model = k.to_s.split "->"
        unless model
          #todo: get datatype..thats a little bit tricky at this point
#          v.gsub!("*",".")
#          a,db_field= v.to_s.split "."
#          t = eval("#{model}.columns_hash[db_field.to_s].type.to_s.downcase")
#          dtypes[k.to_s]="xsd:#{@mapping[t]}"
        end 
      else
        dtypes[k.to_s]=dtypes[v.to_s]
      end
    end
    dtypes
  end

  def get_rows
    #make filter

    t = @model
    return t if t.class == Array
    filter = get_filter(true)
    include = get_include
      
    if include.empty?
      if filter
        t = t.find(:all, :conditions =>filter)
      else
        t = t.find(:all)
      end  
    else
      if filter
        t = t.find(:all,:include => include, :conditions => filter)
      else
        t = t.find(:all,:include => include)
      end    
    end
    t
  end

  def get_row_by_id id
    #make filter
    t = @model
    filter = get_filter(true)
    include = get_include
    find_command = "find_all_by_#{get_key.to_s.downcase}"

    if include.empty?
      if filter
        t = eval("t.#{find_command}(#{id}, :conditions =>filter)")
      else
        t = eval("t.#{find_command}(#{id})")
      end
    else
      if filter
        t = eval("t.#{find_command}(#{id},:include => include, :conditions => filter)")
      else
        t = eval("t.#{find_command}(\"#{id}\",:include => include)")
      end
    end
    t
  end
  
  def get_key
    id_keys = @model_attributes.to_hash.keys
    #hotfix..bad performance
    id_keys.map!{|k| k.to_s }
    id_key= id_keys.select{|k| k =~/^(ID|id|iD|Id)$/ }
    return :id if id_key.empty?
    return @model_attributes[id_key[0].to_sym]      
  end
  
end
