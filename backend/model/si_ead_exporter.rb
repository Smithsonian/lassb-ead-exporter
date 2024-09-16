# encoding: utf-8
require 'nokogiri'
require 'securerandom'

class EADSerializer < ASpaceExport::Serializer
  serializer_for :ead

  # MODIFICATION: Add @type for EDAN object_type processing
  def serialize_extents(obj, xml, fragments)
    if obj.extents.length
      obj.extents.each do |e|
        next if e["publish"] === false && !@include_unpublished
        audatt = e["publish"] === false ? {:audience => 'internal'} : {}

        extent_number_float = e['number'].to_f
        extent_type = I18n.t('enumerations.extent_extent_type.'+e['extent_type'], :default => e['extent_type'])

        xml.physdesc({:altrender => e['portion']}.merge(audatt)) {
          if e['number'] && e['extent_type']
            xml.extent({:type => extent_type}) {
              sanitize_mixed_content("#{e['number']} #{extent_type}", xml, fragments)
            }
          end
          if e['container_summary']
            xml.extent({:altrender => 'carrier'}) {
              sanitize_mixed_content( e['container_summary'], xml, fragments)
            }
          end
          xml.physfacet { sanitize_mixed_content(e['physical_details'], xml, fragments) } if e['physical_details']
          xml.dimensions  { sanitize_mixed_content(e['dimensions'], xml, fragments) } if e['dimensions']
        }
      end
    end
  end

  # MODIFICATION: use new agent record identifier field for authfilenumber AND source, rather than agent name authority ID value, which is still ASpace's default even in 3.x, for whatever reason.
  # Should update this so that the code is modularized, but not right now.
  def serialize_origination(data, xml, fragments)
    unless data.creators_and_sources.nil?
      data.creators_and_sources.each do |link|
        agent = link['_resolved']
        published = agent['publish'] === true

        next if !published && !@include_unpublished

        link['role'] == 'creator' ? role = link['role'].capitalize : role = link['role']
        title = 'title' if link['title']
        relator = [title, link['relator']].compact.reject(&:empty?).join(' ')
        sort_name = agent['display_name']['sort_name']
        sort_name << ". #{link['title']}" if link['title']
        rules = agent['display_name']['rules']
        # NEW, begin
        agent['agent_type'] = 'name' if link['title']
        source = agent['agent_record_identifiers'].select {|i| i['primary_identifier'] == true}.map {|s| s['source']}.first
        authfilenumber = agent['agent_record_identifiers'].select {|i| i['primary_identifier'] == true}.map {|ri| ri['record_identifier']}.first
        # NEW, end
        node_name = case agent['agent_type']
                    when 'agent_person'; 'persname'
                    when 'agent_family'; 'famname'
                    when 'agent_corporate_entity'; 'corpname'
                    when 'agent_software', 'name'; 'name'
                    end

        origination_attrs = {:label => role}
        origination_attrs[:audience] = 'internal' unless published
        xml.origination(origination_attrs) {
          atts = {:role => relator, :source => source, :rules => rules, :authfilenumber => authfilenumber}
          atts.reject! {|k, v| v.nil?}

          xml.send(node_name, atts) {
            sanitize_mixed_content(sort_name, xml, fragments )
          }
        }
      end
    end
  end

  def serialize_external_docs(data, xml, fragments, include_unpublished)
    data.external_documents.each do |ext_doc|
      return if ext_doc['publish'] === false && !include_unpublished
      note_atts = {}
      note_atts['label'] = 'See Also'
      note_atts['altrender'] = 'external_documents'
      note_atts['audience'] = 'internal' if ext_doc['publish'] === false

      link_atts = {}
      link_atts['xlink:href'] = ext_doc['location']
      link_atts['xlink:title'] = ext_doc['title']
      link_atts['altrender'] = 'online_media'

      xml.note (note_atts) {
        xml.p {xml.extref(link_atts) { xml.text (ext_doc['title']) }}
      }
    end
  end

  def serialize_rights(data, xml, fragments, include_unpublished)
    data.rights_statements.each do |rts_stmt|
      all_unpublished = rts_stmt.dig('notes').map { |n| n['publish'] }.all?(false)
      return if all_unpublished && !include_unpublished

      xml.userestrict({ id: "aspace_#{rts_stmt['identifier']}", type: rts_stmt['rights_type'] }) {
        xml.head('Rights Statement')

        rts_stmt['notes'].each do |note|
          next if note['publish'] === false && !include_unpublished

          atts = {}
          atts['type'] = note['type']
          atts['audience'] = 'internal' if note['publish'] === false

          xml.note(atts) {
            xml.p {
              note['content'].each do |c|
                sanitize_mixed_content(c, xml, fragments)
              end
            }
          }
        end

        xml.list {
          xml.item {
            xml.date({ type: 'start', normal: rts_stmt['start_date'] }) if rts_stmt['start_date']
            xml.date({ type: 'end', normal: rts_stmt['end_date'] }) if rts_stmt['end_date']
          }
        }
      }
    end
  end

end
