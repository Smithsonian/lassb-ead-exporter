class SIEADSerialize < EADSerializer

  def call(data, xml, fragments, context, include_unpublished)
    # MODIFICATION: Add external documents to note within <c>'s (not exported by default).
    if context == :c
      data.external_documents.each do |ext_doc|
        return if ext_doc["publish"] === false && !@include_unpublished
        atts = {}
        atts['xlink:href'] = ext_doc['location']
        atts['xlink:title'] = ext_doc['title']
        atts['altrender'] = 'online_media'

        xml.note ({:label => 'See Also', :altrender => 'external_documents'}) {
            xml.p {xml.extref(atts) { xml.text (ext_doc['title']) }}
          }
      end

      if data.rights_statements
        serialize_rights(data, xml, fragments, include_unpublished)
      end

    # MODIFICATION: Add external documents to note within <archdesc> (not exported by default).
    elsif context == :archdesc
      if data.external_documents
        data.external_documents.each do |ext_doc|
          return if ext_doc["publish"] === false && !@include_unpublished
          atts = {}
          atts['xlink:href'] = ext_doc['location']
          atts['xlink:title'] = ext_doc['title']
          atts['altrender'] = 'online_media'

          xml.note ({:label => 'See Also', :altrender => 'external_documents'}) {
              xml.p {xml.extref(atts) { xml.text (ext_doc['title']) }}
            }
        end
      end

      if data.rights_statements
        serialize_rights(data, xml, fragments, include_unpublished)
      end
    end
  end

end
