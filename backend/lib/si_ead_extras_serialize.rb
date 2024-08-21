class SIEADSerialize

  def call(data, xml, fragments, context)
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
    end
  end

end
