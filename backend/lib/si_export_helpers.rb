module ASpaceExport
  # Convenience methods that will work for resource
  # or archival_object models during serialization

  module ArchivalObjectDescriptionHelpers

    # MODIFICATION: add cultural_context as a subject, rather than geogname, which is ASpace's default.
    # MODIFICATION: add temporal as a subject (not exported by default).
    # MODIFICATION: add altrender="term_type".
    def controlaccess_subjects
      unless @controlaccess_subjects
        results = []
        linked = self.subjects || []
        linked.each do |link|
          subject = link['_resolved']

          node_name = case subject['terms'][0]['term_type']
                      when 'function'; 'function'
                      when 'genre_form', 'style_period'; 'genreform'
                      when 'geographic'; 'geogname'
                      when 'occupation'; 'occupation'
                      when 'topical', 'temporal', 'cultural_context'; 'subject'
                      when 'uniform_title'; 'title'
                      else; nil
                      end

          next unless node_name

          content = subject['terms'].map {|t| t['term']}.join(' -- ')

          atts = {}
          atts['source'] = subject['source'] if subject['source']
          atts['authfilenumber'] = subject['authority_id'] if subject['authority_id']
          atts['altrender'] = subject['terms'][0]['term_type'] if subject['terms'][0]['term_type']

          results << {:node_name => node_name, :atts => atts, :content => content}
        end

        @controlaccess_subjects = results
      end

      @controlaccess_subjects
    end

    # MODIFICATION: use new agent record identifier field for authfilenumber AND source, rather than agent name authority ID value, which is still ASpace's default even in 3.x, for whatever reason.
    # Should also fix that strange 'fmo' issue, but later.
    def controlaccess_linked_agents(include_unpublished = false)
      unless @controlaccess_linked_agents
        results = []
        linked = self.linked_agents || []
        linked.each_with_index do |link, i|
          next if link['role'] == 'creator' || (link['_resolved']['publish'] == false && !include_unpublished)
          title = 'title' if link['title']
          relator = link['relator'] ? link['relator'] : (link['role'] == 'source' ? 'fmo' : nil)
          role = [title, relator].compact.reject(&:empty?).join(' ')

          agent = link['_resolved'].dup
          sort_name = agent['display_name']['sort_name']
          sort_name << ". #{link['title']}" if link['title']
          rules = agent['display_name']['rules']
          # NEW, begin
          agent['agent_type'] = 'name' if link['title']
          source = agent['agent_record_identifiers'].select {|i| i['primary_identifier'] == true}.map {|s| s['source']}.first
          authfilenumber = agent['agent_record_identifiers'].select {|i| i['primary_identifier'] == true}.map {|ri| ri['record_identifier']}.first
          # NEW, end
          content = sort_name.dup

          if link['terms'].length > 0
            content << " -- "
            content << link['terms'].map {|t| t['term']}.join(' -- ')
          end

          node_name = case agent['agent_type']
                      when 'agent_person'; 'persname'
                      when 'agent_family'; 'famname'
                      when 'agent_corporate_entity'; 'corpname'
                      when 'agent_software', 'name'; 'name'
                      end

          atts = {}
          atts[:role] = role if role
          atts[:source] = source if source
          atts[:rules] = rules if rules
          atts[:authfilenumber] = authfilenumber if authfilenumber
          atts[:audience] = 'internal' if link['_resolved']['publish'] == false

          results << {:node_name => node_name, :atts => atts, :content => content}
        end

        @controlaccess_linked_agents = results
      end

      @controlaccess_linked_agents
    end

  end
end
