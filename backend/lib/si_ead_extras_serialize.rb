class SIEADSerialize < EADSerializer

  def call(data, xml, fragments, context, include_unpublished)
    # MODIFICATION: Add external documents to note within <c>'s (not exported by default).
    if context == :c
      if data.external_documents
        serialize_external_docs(data, xml, fragments, include_unpublished)
      end

      if data.rights_statements
        serialize_rights(data, xml, fragments, include_unpublished)
      end

    # MODIFICATION: Add external documents to note within <archdesc> (not exported by default).
    elsif context == :archdesc
      if data.external_documents
        serialize_external_docs(data, xml, fragments, include_unpublished)
      end

      if data.rights_statements
        serialize_rights(data, xml, fragments, include_unpublished)
      end
    end
  end

end
