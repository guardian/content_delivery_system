# frozen_string_literal: true

require 'nokogiri'

# <AccessControlListDocument>
# <access id="KP-7095">
# <loc>http://dc1-mmlb-02.dc1.gnm.int:8080/API/collection/KP-126/access/KP-7095</loc>
# <recursive>true</recursive>
# <permission>OWNER</permission>
# <user>Johan_Westerlund</user>
# </access>
# </AccessControlListDocument>

# constants for permission types
ACL_PERM_OWNER = 'OWNER'
ACL_PERM_READ = 'READ'
ACL_PERM_READWRITE = 'WRITE'
ACL_PERM_NONE = 'NONE'

# ACLs are properties of objects, so this class does not do its own interfacing to Vidispine. It just represents the data.
class VSACL
  include Enumerable

  def initialize(xmldoc: nil)
    @items = nil

    # xpath.each
    xmldoc&.xpath('//vs:access', 'vs' => 'http://xml.vidispine.com/schema/vidispine')&.each do |chunk|
      @items << VSAccess.new(xmldoc: chunk)
    end # if(xmldoc)
  end # def initialize

  def add(access)
    raise ArgumentError unless access.is_a?(VSAccess)

    @items << access
  end

  def to_xml
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.AccessControlListDocument('xmlns' => 'http://xml.vidispine.com/schema/vidispine') do
        @items.each do |access|
          access.to_xml(xml)
        end # @items.each
      end
    end # XML::Builder.new
    builder.to_xml
  end # to_xml

  def each(&block)
    @items.each do |i|
      block.call(i)
    end
  end
end # class VSACL

class VSAccess
  attr_accessor :user
  attr_accessor :permission
  attr_accessor :recursive
  attr_accessor :id

  def initialize(user: nil, group: nil, permission: nil, recursive: false, xmldoc: nil)
    if xmldoc
      @id = xmldoc.xpath('//vs:id', 'vs' => 'http://xml.vidispine.com/schema/vidispine').text
      @user = xmldoc.xpath('//vs:user', 'vs' => 'http://xml.vidispine.com/schema/vidispine')
      @group = xmldoc.xpath('//vs:group', 'vs' => 'http://xml.vidispine.com/schema/vidispine')
      @permission = xmldoc.xpath('//vs:permission', 'vs' => 'http://xml.vidispine.com/schema/vidispine')
      recursive_text = xmldoc.xpath('//vs:recursive', 'vs' => 'http://xml.vidispine.com/schema/vidispine')
      @recursive = recursive_text.downcase == 'true'

      return
    end # if(xmldoc)

    @user = user
    @group = group
    @permission = permission
    @recursive = recursive
    @id = nil
  end

  def to_xml(builder: nil)
    if builder
      builder.access do
        xml.recursive(@recursive)
        xml.permission(@permission)
        xml.user(@user) if @user
        xml.group(@group) if @group
      end
      nil
    else
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.AccessControlDocument('xmlns' => 'http://xml.vidispine.com/schema/vidispine') do
          xml.recursive(@recursive)
          xml.permission(@permission)
          xml.user(@user) if @user
          xml.group(@group) if @group
        end
      end # builder
      builder.to_xml
    end
  end # to_xml
end # class VSAccess
