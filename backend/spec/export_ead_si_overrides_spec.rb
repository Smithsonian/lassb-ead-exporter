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
                      :external_documents => [build(:json_external_document, {:publish => true})]
                      )

    @resource = JSONModel(:resource).find(resource.id)

    @archival_object = create(:json_archival_object,
                              :resource => {:ref => @resource.uri},
                              :publish => true,
                              :external_documents => [build(:json_external_document, {:publish => true})])
  end

  def doc(use_namespaces = false)
    use_namespaces ? @doc : @doc_nsless
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
          @doc = get_xml("/repositories/#{$repo_id}/resource_descriptions/#{@resource.id}.xml?include_unpublished=true&include_daos=true")

          @doc_nsless = Nokogiri::XML::Document.parse(@doc.to_xml)
          @doc_nsless.remove_namespaces!
          raise Sequel::Rollback
        end
      end
      expect(@doc.errors.length).to eq(0)

      # if the word Nokogiri appears in the XML file, we'll assume something
      # has gone wrong
      expect(@doc.to_xml).not_to include("Nokogiri")
      expect(@doc.to_xml).not_to include("#&amp;")
    end
  end

  describe 'Within <origination>' do
    it "exports agent_record_identifers['primary_identifier']['source'] to <persname>/<corpname>/<famname> source attribute" do
      expect(doc.at_xpath("//origination/persname/@source").content).
        to match(@creator_agent.agent_record_identifiers.first['source'])
    end

    it "exports agent_record_identifers['primary_identifier']['record_identifier'] to <persname>/<corpname>/<famname> authfilenumber attribute" do
      expect(doc.at_xpath("//origination/persname/@authfilenumber").content).
        to match(@creator_agent.agent_record_identifiers.first['record_identifier'])
    end

    it "exports linked agent title as <name role='title'" do
      expect(doc.at_xpath("//origination/name/@role").content).
        to match('title')
      expect(doc.at_xpath("//origination/name").text()).
        to match("#{@creator_agent_with_title.title}. My agent title")
    end
  end

  describe 'Within <physdesc>' do
    it 'exports extent_type to <extent> type attribute' do
      expect(doc.at_xpath("//physdesc/extent/@type").content).
        to match(@extents.first.extent_type.gsub('_', ' ').titlecase)
    end
  end

  describe 'Within <controlaccess>' do
    it "exports agent_record_identifers['primary_identifier']['source'] to <persname>/<corpname>/<famname> source attribute" do
      expect(doc.at_xpath("//controlaccess/famname/@source").content).
        to match(@subject_agent.agent_record_identifiers.first['source'])
    end

    it "exports agent_record_identifers['primary_identifier']['record_identifier'] to <persname>/<corpname>/<famname> authfilenumber attribute" do
      expect(doc.at_xpath("//controlaccess/famname/@authfilenumber").content).
        to match(@subject_agent.agent_record_identifiers.first['record_identifier'])
    end

    it "exports subjects with the term_type 'cultural_context' to <subject>" do
      expect(doc.at_xpath("//controlaccess/subject[@altrender = 'cultural_context']").text()).
        to match(@cultural_subject.title)
    end

    it "exports subjects with the term_type 'temporal' to <subject>" do
      expect(doc.at_xpath("//controlaccess/subject[@altrender = 'temporal']").text()).
        to match(@temporal_subject.title)
    end

    it 'exports subject term type into altrender attribute' do
      expect(doc.at_xpath("//controlaccess/geogname/@altrender").content).
        to match('geographic')
    end

    it "exports linked agent title as <name role='title'" do
      expect(doc.at_xpath("//controlaccess/name/@role").content).
        to match('title')
      expect(doc.at_xpath("//controlaccess/name").text()).
        to start_with("#{@subject_agent_with_title.title}. My subject agent title")
    end
  end

  describe 'Within <archdesc>' do
    it 'exports external_documents to <note>' do
      expect(doc.at_xpath("/ead/archdesc/note[@altrender='external_documents']/@label").content).
        to match('See Also')
      expect(doc.at_xpath("/ead/archdesc/note[@altrender='external_documents']/p/extref/@altrender").content).
        to match('online_media')
      expect(doc.at_xpath("/ead/archdesc/note[@altrender='external_documents']/p/extref/@href").content).
        to match(@resource.external_documents.first['location'])
      expect(doc.at_xpath("/ead/archdesc/note[@altrender='external_documents']/p/extref/@title").content).
        to match(@resource.external_documents.first['title'])
      expect(doc.at_xpath("/ead/archdesc/note[@altrender='external_documents']/p/extref/@title").text()).
        to match(@resource.external_documents.first['title'])
    end
  end

  describe 'Within <c>' do
    it 'exports external_documents to <note>' do
      expect(doc.at_xpath("/ead/archdesc/dsc/c/note[@altrender='external_documents']/@label").content).
        to match('See Also')
      expect(doc.at_xpath("/ead/archdesc/dsc/c/note[@altrender='external_documents']/p/extref/@altrender").content).
        to match('online_media')
      expect(doc.at_xpath("/ead/archdesc/dsc/c/note[@altrender='external_documents']/p/extref/@href").content).
        to match(@archival_object.external_documents.first['location'])
      expect(doc.at_xpath("/ead/archdesc/dsc/c/note[@altrender='external_documents']/p/extref/@title").content).
        to match(@archival_object.external_documents.first['title'])
      expect(doc.at_xpath("/ead/archdesc/dsc/c/note[@altrender='external_documents']/p/extref/@title").text()).
        to match(@archival_object.external_documents.first['title'])
    end
  end
end
