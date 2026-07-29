class EADSerializer < ASpaceExport::Serializer
  # All this patching is only necessary for as long as core ArchivesSpace doesn't pass along `@include_unpublished` to
  # our plugin export class(es).  So, once that's merged in upstream, none of this will be necessary anymore.
  # See: https://github.com/archivesspace/archivesspace/pull/3315
  if method(:run_serialize_step).arity < 5

    serializer_for :ead

    def self.run_serialize_step(data, xml, fragments, context, include_unpublished = false)
      Array(@extra_serialize_steps).each do |step|
        # Adding in check so as not to break existing plugins missing `include_unpublished`
        if step.new.method(:call).arity == 4
          step.new.call(data, xml, fragments, context)
        else
          step.new.call(data, xml, fragments, context, include_unpublished)
        end
      end
    end

    def stream(data)
      @stream_handler = ASpaceExport::StreamHandler.new
      @fragments = ASpaceExport::RawXMLHandler.new
      @include_unpublished = data.include_unpublished?
      @include_daos = data.include_daos?
      @use_numbered_c_tags = data.use_numbered_c_tags?
      @id_prefix = I18n.t('archival_object.ref_id_export_prefix', :default => 'aspace_')

      doc = Nokogiri::XML::Builder.new(:encoding => "UTF-8") do |xml|
        ead_attributes = {
          'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
          'xsi:schemaLocation' => 'urn:isbn:1-931666-22-9 http://www.loc.gov/ead/ead.xsd',
          'xmlns:xlink' => 'http://www.w3.org/1999/xlink'
        }

        if data.publish === false
          ead_attributes['audience'] = 'internal'
        end

        xml.ead( ead_attributes ) {

          xml.text (
    @stream_handler.buffer { |xml, new_fragments|
      serialize_eadheader(data, xml, new_fragments)
    })

          atts = {:level => data.level, :otherlevel => data.other_level}
          atts.reject! {|k, v| v.nil?}

          xml.archdesc(atts) {

            xml.did {

              if (val = data.repo.name)
                xml.repository {
                  xml.corpname { sanitize_mixed_content(val, xml, @fragments) }
                }
              end

              if (val = data.title)
                xml.unittitle { sanitize_mixed_content(val, xml, @fragments) }
              end

              serialize_origination(data, xml, @fragments)

              xml.unitid (0..3).map {|i| data.send("id_#{i}")}.compact.join('.')

              if @include_unpublished
                data.external_ids.each do |exid|
                  xml.unitid ({ "audience" => "internal", "type" => exid['source'], "identifier" => exid['external_id']}) { xml.text exid['external_id']}
                end
              end

              handle_arks(data, xml)

              serialize_extents(data, xml, @fragments)

              serialize_dates(data, xml, @fragments)

              serialize_did_notes(data, xml, @fragments)

              if (languages = data.lang_materials)
                serialize_languages(languages, xml, @fragments)
              end

              data.instances_with_sub_containers.each do |instance|
                serialize_container(instance, xml, @fragments)
              end

              EADSerializer.run_serialize_step(data, xml, @fragments, :did, @include_unpublished)

            }# </did>

            data.digital_objects.each do |dob|
              serialize_digital_object(dob, xml, @fragments)
            end

            serialize_nondid_notes(data, xml, @fragments)

            serialize_bibliographies(data, xml, @fragments)

            serialize_indexes(data, xml, @fragments)

            serialize_controlaccess(data, xml, @fragments)

            EADSerializer.run_serialize_step(data, xml, @fragments, :archdesc, @include_unpublished)

            xml.dsc {

              data.children_indexes.each do |i|
                xml.text(
                  @stream_handler.buffer {|xml, new_fragments|
                    serialize_child(data.get_child(i), xml, new_fragments)
                  }
                )
              end
            }
          }
        }
      end
      doc.doc.root.add_namespace nil, 'urn:isbn:1-931666-22-9'

      Enumerator.new do |y|
        @stream_handler.stream_out(doc, @fragments, y)
      end
    end

    def serialize_child(data, xml, fragments, c_depth = 1)
      return if data["publish"] === false && !@include_unpublished
      return if data["suppressed"] === true

      tag_name = @use_numbered_c_tags ? :"c#{c_depth.to_s.rjust(2, '0')}" : :c

      atts = {:level => data.level, :otherlevel => data.other_level, :id => prefix_id(data.ref_id)}

      if data.publish === false
        atts[:audience] = 'internal'
      end

      atts.reject! {|k, v| v.nil?}
      xml.send(tag_name, atts) {

        xml.did {
          if (val = data.title)
            xml.unittitle { sanitize_mixed_content( val, xml, fragments) }
          end

          if !data.component_id.nil? && !data.component_id.empty?
            xml.unitid data.component_id
          end

          handle_arks(data, xml)

          if @include_unpublished
            data.external_ids.each do |exid|
              xml.unitid ({ "audience" => "internal", "type" => exid['source'], "identifier" => exid['external_id']}) { xml.text exid['external_id']}
            end
          end

          serialize_origination(data, xml, fragments)
          serialize_extents(data, xml, fragments)
          serialize_dates(data, xml, fragments)
          serialize_did_notes(data, xml, fragments)

          if (languages = data.lang_materials)
            serialize_languages(languages, xml, fragments)
          end

          EADSerializer.run_serialize_step(data, xml, fragments, :did, @include_unpublished)

          data.instances_with_sub_containers.each do |instance|
            serialize_container(instance, xml, @fragments)
          end

          if @include_daos
            data.instances_with_digital_objects.each do |instance|
              serialize_digital_object(instance['digital_object']['_resolved'], xml, fragments)
            end
          end
        }

        serialize_nondid_notes(data, xml, fragments)

        serialize_bibliographies(data, xml, fragments)

        serialize_indexes(data, xml, fragments)

        serialize_controlaccess(data, xml, fragments)

        EADSerializer.run_serialize_step(data, xml, fragments, :archdesc, @include_unpublished)

        data.children_indexes.each do |i|
          xml.text(
            @stream_handler.buffer {|xml, new_fragments|
              serialize_child(data.get_child(i), xml, new_fragments, c_depth + 1)
            }
          )
        end
      }
    end

  end

end
