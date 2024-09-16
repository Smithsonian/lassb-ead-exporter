# encoding: utf-8
require 'nokogiri'
require 'spec_helper'
require_relative '../../../../backend/spec/export_spec_helper'

# Used to check that the fields EAD needs resolved are being resolved by the indexer.
require_relative '../../../../indexer/app/lib/indexer_common_config'

describe 'SI EAD export mappings' do

  #######################################################################
  # FIXTURES
  #######################################################################

  def load_export_fixtures
    @extents = [ build(:json_extent) ]

    @creator_agent = create(:json_agent_person,
                            :agent_record_identifiers => [ build(:agent_record_identifier, primary_identifier: true)],
                            :publish => true)
    @creator_agent_with_title = create(:json_agent_corporate_entity,
                                       :publish => true)
    @subject_agent = create(:json_agent_family,
                            :agent_record_identifiers => [ build(:agent_record_identifier, primary_identifier: true)],
                            :publish => true)
    @subject_agent_with_title = create(:json_agent_person,
                                       :publish => true)

    @cultural_subject = create(:json_subject,
                               :terms => [build(:json_term, :term_type => 'cultural_context')])
    @temporal_subject = create(:json_subject,
                               :terms => [build(:json_term, :term_type => 'temporal')])
    @geographic_subject = create(:json_subject,
                                 :terms => [build(:json_term, :term_type => 'geographic')])

    @published_note = build(:json_note_rights_statement, publish: true)
    @unpublished_note = build(:json_note_rights_statement, publish: false)

    @published_external_doc = build(:json_external_document, publish: true)
    @unpublished_external_doc = build(:json_external_document, publish: false)

    resource = create(:json_resource,
                      :extents => @extents,
                      :linked_agents => [{ :ref => @creator_agent.uri,
                                           :role => 'creator',
                                           :terms => [build(:json_term), build(:json_term)],
                                           :relator => generate(:relator) },
                                         { :ref => @subject_agent.uri,
                                           :role => 'subject',
                                           :terms => [build(:json_term), build(:json_term)],
                                           :relator => generate(:relator) },
                                         { :ref => @creator_agent_with_title.uri,
                                           :role => 'creator',
                                           :title => 'My agent title',
                                           :terms => [build(:json_term), build(:json_term)],
                                           :relator => generate(:relator) },
                                         { :ref => @subject_agent_with_title.uri,
                                           :role => 'subject',
                                           :title => 'My subject agent title',
                                           :terms => [build(:json_term), build(:json_term)],
                                           :relator => generate(:relator) }],
                      :subjects => [{ :ref => @cultural_subject.uri },
                                    { :ref => @temporal_subject.uri },
                                    { :ref => @geographic_subject.uri }],
                      :publish => true,
                      :external_documents => [@published_external_doc,
                                              @unpublished_external_doc],
                      :rights_statements => [build(:json_rights_statement,
                                                   notes: [@published_note,
                                                           @unpublished_note])]
                      )

    @resource = JSONModel(:resource).find(resource.id)

    @archival_object = create(:json_archival_object,
                              :resource => {:ref => @resource.uri},
                              :publish => true,
                              :external_documents => [@published_external_doc,
                                                      @unpublished_external_doc],
                              :rights_statements => [build(:json_rights_statement,
                                                           notes: [@published_note,
                                                                   @unpublished_note])]
                              )
  end

  def doc_unpublished
    Nokogiri::XML::Document.parse(@doc_unpublished.to_xml).remove_namespaces!
  end

  def doc_published
    Nokogiri::XML::Document.parse(@doc_published.to_xml).remove_namespaces!
  end

  before(:all) do
    as_test_user('admin') do
      RSpec::Mocks.with_temporary_scope do
        # EAD export normally tries the search index first, but for the tests we'll
        # skip that since Solr isn't running.
        allow(Search).to receive(:records_for_uris) do |*|
          {'results' => []}
        end

        as_test_user("admin", true) do
          load_export_fixtures
          @doc_unpublished = get_xml("/repositories/#{$repo_id}/resource_descriptions/#{@resource.id}.xml?include_unpublished=true&include_daos=true")
          @doc_published = get_xml("/repositories/#{$repo_id}/resource_descriptions/#{@resource.id}.xml?include_unpublished=false&include_daos=true")

          raise Sequel::Rollback
        end
      end
      expect(@doc_unpublished.errors.length).to eq(0)
      expect(@doc_published.errors.length).to eq(0)

      # if the word Nokogiri appears in the XML file, we'll assume something
      # has gone wrong
      expect(@doc_unpublished.to_xml).not_to include("Nokogiri")
      expect(@doc_unpublished.to_xml).not_to include("#&amp;")
      expect(@doc_published.to_xml).not_to include("Nokogiri")
      expect(@doc_published.to_xml).not_to include("#&amp;")
    end
  end

  describe 'Within <origination>' do
    it "exports agent_record_identifers['primary_identifier']['source'] to <persname>/<corpname>/<famname> source attribute" do
      expect(doc_unpublished.at_xpath("//origination/persname/@source").content).
        to match(@creator_agent.agent_record_identifiers.first['source'])
    end

    it "exports agent_record_identifers['primary_identifier']['record_identifier'] to <persname>/<corpname>/<famname> authfilenumber attribute" do
      expect(doc_unpublished.at_xpath("//origination/persname/@authfilenumber").content).
        to match(@creator_agent.agent_record_identifiers.first['record_identifier'])
    end

    it "exports linked agent title as <name role='title'" do
      creator_agent_link = @resource.linked_agents.select { |a| a['ref'] == @creator_agent_with_title.uri }.first
      expect(doc_unpublished.at_xpath("//origination/name/@role").content).
        to match("title #{creator_agent_link['relator']}")
      expect(doc_unpublished.at_xpath("//origination/name").text()).
        to match("#{@creator_agent_with_title.title}. My agent title")
    end
  end

  describe 'Within <physdesc>' do
    it 'exports extent_type to <extent> type attribute' do
      expect(doc_unpublished.at_xpath("//physdesc/extent/@type").content).
        to match(@extents.first.extent_type.gsub('_', ' ').titlecase)
    end
  end

  describe 'Within <controlaccess>' do
    it "exports agent_record_identifers['primary_identifier']['source'] to <persname>/<corpname>/<famname> source attribute" do
      expect(doc_unpublished.at_xpath("//controlaccess/famname/@source").content).
        to match(@subject_agent.agent_record_identifiers.first['source'])
    end

    it "exports agent_record_identifers['primary_identifier']['record_identifier'] to <persname>/<corpname>/<famname> authfilenumber attribute" do
      expect(doc_unpublished.at_xpath("//controlaccess/famname/@authfilenumber").content).
        to match(@subject_agent.agent_record_identifiers.first['record_identifier'])
    end

    it "exports subjects with the term_type 'cultural_context' to <subject>" do
      expect(doc_unpublished.at_xpath("//controlaccess/subject[@altrender = 'cultural_context']").text()).
        to match(@cultural_subject.title)
    end

    it "exports subjects with the term_type 'temporal' to <subject>" do
      expect(doc_unpublished.at_xpath("//controlaccess/subject[@altrender = 'temporal']").text()).
        to match(@temporal_subject.title)
    end

    it 'exports subject term type into altrender attribute' do
      expect(doc_unpublished.at_xpath("//controlaccess/geogname/@altrender").content).
        to match('geographic')
    end

    it "exports linked agent title as <name role='title'" do
      subject_agent_link = @resource.linked_agents.select { |a| a['ref'] == @subject_agent_with_title.uri }.first
      expect(doc_unpublished.at_xpath("//controlaccess/name/@role").content).
        to match("title #{subject_agent_link['relator']}")
      expect(doc_unpublished.at_xpath("//controlaccess/name").text()).
        to start_with("#{@subject_agent_with_title.title}. My subject agent title")
    end
  end

  describe 'Within <archdesc>' do
    let(:unpublished_external_doc) { doc.at_xpath("/ead/archdesc/note[@altrender='external_documents' and @audience='internal']") }
    let(:published_external_doc) { doc.at_xpath("/ead/archdesc/note[@altrender='external_documents' and not(@audience='internal')]") }
    let(:unpublished_note) { doc.at_xpath("/ead/archdesc/userestrict/note[@audience='internal']") }
    let(:published_note) { doc.at_xpath("/ead/archdesc/userestrict/note[not(@audience='internal')]") }

    context 'when including unpublished' do
      let(:doc) { doc_unpublished }

      it 'includes published and unpublished external documents' do
        expect(doc.xpath("/ead/archdesc/note[@altrender='external_documents']").count).to eq(2)
      end

      it 'includes published and unpublished userestrict notes' do
        expect(doc.xpath("/ead/archdesc/userestrict/note").count).to eq(2)
      end

      describe 'the unpublished external document' do
        it 'has an audience of internal' do
          expect(unpublished_external_doc.at_xpath("@audience").content).to eq('internal')
        end

        it 'exports the unpublished external_documents to <note>' do
          expect(unpublished_external_doc.at_xpath("@label").content).
            to match('See Also')
          expect(unpublished_external_doc.at_xpath("p/extref/@altrender").content).
            to match('online_media')
          expect(unpublished_external_doc.at_xpath("p/extref/@href").content).
            to match(@unpublished_external_doc['location'])
          expect(unpublished_external_doc.at_xpath("p/extref/@title").content).
            to match(@unpublished_external_doc['title'])
          expect(unpublished_external_doc.at_xpath("p/extref/@title").text()).
            to match(@unpublished_external_doc['title'])
        end
      end

      describe 'the published external document' do
        it 'exports the published external_documents to <note>' do
          expect(published_external_doc.at_xpath("@label").content).
            to match('See Also')
          expect(published_external_doc.at_xpath("p/extref/@altrender").content).
            to match('online_media')
          expect(published_external_doc.at_xpath("p/extref/@href").content).
            to match(@published_external_doc['location'])
          expect(published_external_doc.at_xpath("p/extref/@title").content).
            to match(@published_external_doc['title'])
          expect(published_external_doc.at_xpath("p/extref/@title").text()).
            to match(@published_external_doc['title'])
        end
      end

      describe 'the unpublished note' do
        it 'has an audience of internal' do
          expect(unpublished_note.at_xpath("@audience").content).to eq('internal')
        end

        it 'exports correctly' do
          expect(unpublished_note.content).to match(@unpublished_note.content.join(''))
          expect(unpublished_note.at_xpath("@type").content).to match(@unpublished_note.type)
        end
      end

      describe 'the published note' do
        it 'has no audience attribute' do
          expect(published_note.at_xpath("@audience")).to be(nil)
        end

        it 'exports correctly' do
          expect(published_note.content).to match(@published_note.content.join(''))
          expect(published_note.at_xpath("@type").content).to match(@published_note.type)
        end
      end
    end

    context 'when excluding unpublished' do
      let(:doc) { doc_published }

      it 'includes only the published external documents note' do
        expect(doc.xpath("/ead/archdesc/note[@altrender='external_documents']").count).to eq(1)
      end

      it 'includes only the published note' do
        expect(doc.xpath("/ead/archdesc/userestrict/note").count).to eq(1)
      end

      describe 'the unpublished external document' do
        it 'is not exported' do
          expect(unpublished_external_doc).to be(nil)
        end
      end

      describe 'the published external document' do
        it 'has no audience attribute' do
          expect(published_external_doc.at_xpath("@audience")).to be(nil)
        end

        it 'exports external_documents to <note>' do
          expect(published_external_doc.at_xpath("@label").content).
            to match('See Also')
          expect(published_external_doc.at_xpath("p/extref/@altrender").content).
            to match('online_media')
          expect(published_external_doc.at_xpath("p/extref/@href").content).
            to match(@published_external_doc['location'])
          expect(published_external_doc.at_xpath("p/extref/@title").content).
            to match(@published_external_doc['title'])
          expect(published_external_doc.at_xpath("p/extref/@title").text()).
            to match(@published_external_doc['title'])
        end
      end

      describe 'the unpublished note' do
        it 'is not exported' do
          expect(unpublished_note).to be(nil)
        end
      end

      describe 'the published note' do
        it 'has no audience attribute' do
          expect(published_note.at_xpath("@audience")).to be(nil)
        end

        it 'exports correctly' do
          expect(published_note.content).to match(@published_note.content.join(''))
          expect(published_note.at_xpath("@type").content).to match(@published_note.type)
        end
      end
    end
  end

  describe 'Within <c>' do
    let(:unpublished_external_doc) { doc.at_xpath("/ead/archdesc/dsc/c/note[@altrender='external_documents' and @audience='internal']") }
    let(:published_external_doc) { doc.at_xpath("/ead/archdesc/dsc/c/note[@altrender='external_documents' and not(@audience='internal')]") }
    let(:unpublished_note) { doc.at_xpath("/ead/archdesc/dsc/c/userestrict/note[@audience='internal']") }
    let(:published_note) { doc.at_xpath("/ead/archdesc/dsc/c/userestrict/note[not(@audience='internal')]") }

    context 'when including unpublished' do
      let(:doc) { doc_unpublished }

      it 'includes published and unpublished external documents' do
        expect(doc.xpath("/ead/archdesc/dsc/c/note[@altrender='external_documents']").count).to eq(2)
      end

      it 'includes published and unpublished userestrict notes' do
        expect(doc.xpath("/ead/archdesc/dsc/c/userestrict/note").count).to eq(2)
      end

      describe 'the unpublished external document' do
        it 'has an audience of internal' do
          expect(unpublished_external_doc.at_xpath("@audience").content).to eq('internal')
        end

        it 'exports the unpublished external_documents to <note>' do
          expect(unpublished_external_doc.at_xpath("@label").content).
            to match('See Also')
          expect(unpublished_external_doc.at_xpath("p/extref/@altrender").content).
            to match('online_media')
          expect(unpublished_external_doc.at_xpath("p/extref/@href").content).
            to match(@unpublished_external_doc['location'])
          expect(unpublished_external_doc.at_xpath("p/extref/@title").content).
            to match(@unpublished_external_doc['title'])
          expect(unpublished_external_doc.at_xpath("p/extref/@title").text()).
            to match(@unpublished_external_doc['title'])
        end
      end

      describe 'the published external document' do
        it 'exports the published external_documents to <note>' do
          expect(published_external_doc.at_xpath("@label").content).
            to match('See Also')
          expect(published_external_doc.at_xpath("p/extref/@altrender").content).
            to match('online_media')
          expect(published_external_doc.at_xpath("p/extref/@href").content).
            to match(@published_external_doc['location'])
          expect(published_external_doc.at_xpath("p/extref/@title").content).
            to match(@published_external_doc['title'])
          expect(published_external_doc.at_xpath("p/extref/@title").text()).
            to match(@published_external_doc['title'])
        end
      end

      describe 'the unpublished note' do
        it 'has an audience of internal' do
          expect(unpublished_note.at_xpath("@audience").content).to eq('internal')
        end

        it 'exports correctly' do
          expect(unpublished_note.content).to match(@unpublished_note.content.join(''))
          expect(unpublished_note.at_xpath("@type").content).to match(@unpublished_note.type)
        end
      end

      describe 'the published note' do
        it 'has no audience attribute' do
          expect(published_note.at_xpath("@audience")).to be(nil)
        end

        it 'exports correctly' do
          expect(published_note.content).to match(@published_note.content.join(''))
          expect(published_note.at_xpath("@type").content).to match(@published_note.type)
        end
      end
    end

    context 'when excluding unpublished' do
      let(:doc) { doc_published }

      it 'includes only the published external documents note' do
        expect(doc.xpath("/ead/archdesc/dsc/c/note[@altrender='external_documents']").count).to eq(1)
      end

      it 'includes only the published note' do
        expect(doc.xpath("/ead/archdesc/dsc/c/userestrict/note").count).to eq(1)
      end

      describe 'the unpublished external document' do
        it 'is not exported' do
          expect(unpublished_external_doc).to be(nil)
        end
      end

      describe 'the published external document' do
        it 'has no audience attribute' do
          expect(published_external_doc.at_xpath("@audience")).to be(nil)
        end

        it 'exports external_documents to <note>' do
          expect(published_external_doc.at_xpath("@label").content).
            to match('See Also')
          expect(published_external_doc.at_xpath("p/extref/@altrender").content).
            to match('online_media')
          expect(published_external_doc.at_xpath("p/extref/@href").content).
            to match(@published_external_doc['location'])
          expect(published_external_doc.at_xpath("p/extref/@title").content).
            to match(@published_external_doc['title'])
          expect(published_external_doc.at_xpath("p/extref/@title").text()).
            to match(@published_external_doc['title'])
        end
      end

      describe 'the unpublished note' do
        it 'is not exported' do
          expect(unpublished_note).to be(nil)
        end
      end

      describe 'the published note' do
        it 'has no audience attribute' do
          expect(published_note.at_xpath("@audience")).to be(nil)
        end

        it 'exports correctly' do
          expect(published_note.content).to match(@published_note.content.join(''))
          expect(published_note.at_xpath("@type").content).to match(@published_note.type)
        end
      end
    end
  end
end
