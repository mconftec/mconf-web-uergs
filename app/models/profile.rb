class Profile < ActiveRecord::Base
  belongs_to :user

  acts_as_taggable
  has_logo

  def local_affordances
    [ :read, :manage ].map{ |a| ActiveRecord::Authorization::Affordance.new(user, a) } +
    user.fellows.map{ |f| ActiveRecord::Authorization::Affordance.new(f, :read) }
  end
 
  def self.atom_parser(data)

    e = Atom::Entry.parse(data)
      
      profile = {}
      profile[:address] = e.get_elem(e.to_xml, "http://sir.dit.upm.es/schema", "address").text
      profile[:city] = e.get_elem(e.to_xml, "http://sir.dit.upm.es/schema", "city").text
      profile[:zipcode] = e.get_elem(e.to_xml, "http://sir.dit.upm.es/schema", "zipcode").text
      profile[:province] = e.get_elem(e.to_xml, "http://sir.dit.upm.es/schema", "province").text
      profile[:country] = e.get_elem(e.to_xml, "http://sir.dit.upm.es/schema", "country").text
      
      e.get_elems(e.to_xml, "http://schemas.google.com/g/2005", "phoneNumber").each do |times|
        type = times.attribute('rel').to_s.sub('http://schemas.google.com/g/2005#', '')
        if type == "home"
          profile[:phone] = times.text 
        else
          profile[type.to_sym] = times.text
        end 
      end

      org = e.get_elem(e.to_xml, "http://schemas.google.com/g/2005", "organization")
      profile[:organization] = org.each_element_with_text('orgName')[0].text

            
    resultado = {}
    
    resultado[:profile] = profile
    
    return resultado     
  end   
  
end
