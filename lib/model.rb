# To change this template, choose Tools | Templates
# and open the template in the editor.
require 'configatron'

class Model
  attr_accessor :model
  attr_accessor :model_name 
  attr_accessor :model_attributes 
  
  def initialize model_name
    @model_name= model_name 
    
    #read the model attributes
    @model_attributes = get_model_attributes model_name
    unless @model_attributes
      h="hello"
    end
    @model = get_model
    
  end
  
  def get_model
    eval(@model_name.to_s)
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
    model_attributes.select {|k,v| k.to_s.include?("->")}.each do |attribute|
      ref_model = attribute[1]
      #get model     
      ret.push(ref_model.downcase.to_sym)
    end
    model_attributes.select {|k,v| v.to_s.include?(".")}.each do |attribute|
      ref_model = attribute[1].split(".")[0]
      #get model
      ret.push(ref_model.downcase.to_sym)
    end
    ret
  end

  def get_model_attributes key
    model_groups =  eval("configatron.query").to_hash
    model_groups.each do |model_group_name,model_group|
      model_group.each do |model_name_query,attributes|
        if model_name_query.to_s.downcase == key.to_s.downcase
          return attributes
        end
      end
    end
    nil
  end

  def read_attributes
    get_model_attributes @model_name
  end
  
  def get_datatypes
    #hard coded mapping look mapping table
    mapping = Hash[ "binary"=>"base64Binary","boolean"=>"boolean","date"=>"date","datetime"=>"dateTime","decimal"=>"decimal","float"=>"float","integer"=>"integer","string"=>"string","text"=>"string","time"=>"time","timestamp"=>"dateTime",]
    dtypes = Hash.new
    @model.columns_hash.each_key do |m|
      #make xsd datatye
      dtypes[m.to_s] ="xsd:#{mapping[@model.columns_hash[m].type.to_s] }"
    end
    #replace mapping
    @model_attributes.each do |k,v|
      dtypes[k.to_s]=dtypes[v.to_s]
    end
    dtypes
  end

  def get_rows
    #make filter
    t = @model
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
  
  def get_key
    id_keys = @model_attributes.to_hash.keys
    #hotfix..bad performance
    id_keys.map!{|k| k.to_s }
    id_key= id_keys.select{|k| k =~/^(ID|id|iD|Id)$/ }
    return :id if id_key.empty?
    return @model_attributes[id_key[0].to_sym]      
  end

#  def extract_id_line model_attributes, line,item,dtypes
#    #look if id is mapped to another field
#    id_keys = model_attributes.to_hash.keys
#    #hotfix..bad performance
#    id_keys.map!{|k| k.to_s }
#    id_key= id_keys.select{|k| k =~/^(ID|id|iD|Id)$/ }
#    if id_key.empty?
#      line[:id] = item.id
#    else
#      line[:id] = eval("item.#{model_attributes[id_key[0].to_sym]}")
#      #set the correct datatype for it
#      dtypes["id"]= line[:id].class.to_s.downcase
#      #remove the id line
#      line.delete id_key[0].to_sym
#    end
#  end


  
end
