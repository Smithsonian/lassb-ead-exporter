# lassb-ead-exporter
This repository is the new home of the previously-named "si-ead-exporter" ArchivesSpace plugin.  

## Overrides

### EAD 2002 Export

_Origination_

1. <a name="one"></a>Within `<origination>`, sets the value of an agent's `source` attribute from `agent_record_identifiers['primary_identifier']['source']`, instead of the ASpace default of `display_name['source']`.
2. <a name="two"></a>Within `<origination>`, sets the value of an agent's `authfilenumber` attribute from `agent_record_identifiers['primary_identifier']['record_identifier']`, instead of the ASpace default `display_name['authority_id']`.

_Extents_

3. <a name="three"></a>Within `<physdesc>`, adds the `extent_type` to an `<extent>`'s type attribute for EDAN object_type processing.  Removes the ASpace default extent attribute of `altrender='materialtype spaceoccupied'`.

_Control Access Subjects_

4. <a name="four"></a>Within `<controlaccess>`, exports subject records with the term_type `cultural_context` as a `<subject>`, instead of the ASpace default of `<geogname>`.
5. <a name="five"></a>Within `<controlaccess>`, exports subject records with the term_type `temporal` as a `<subject>`.  ASpace does not export this by default.
6. <a name="six"></a>Within `<controlaccess>`, adds an `altrender` attribute containing a subject's term type to all subject record exports (no altrender attribute is set by ASpace by default).

_Control Access Linked Agents_

7. <a name="seven"></a>Within `<controlaccess>`, sets the value of an agent's `source` attribute from `agent_record_identifiers['primary_identifier']['source']`, instead of the ASpace default of `display_name['source']`.
8. <a name="eight"></a>Within `<controlaccess>`, sets the value of an agent's `authfilenumber` attribute from `agent_record_identifiers['primary_identifier']['record_identifier']`, instead of the ASpace default `display_name['authority_id']`.

_External Documents_

9. <a name="nine"></a>Within `<archdesc>`, exports an additional `<note altrender="external_documents" label="See Also">` note holding a link to an external document.  The note contains an `<extref altrender="online_media">` inside of `<p>` tags, with the extref's `xlink:href` and `xlink:title` attributes populated from the external document record.  External documents are not exported by ASpace by default.
10. <a name="ten"></a>Within `<c>`, exports an additional `<note altrender="external_documents" label="See Also">` note holding a link to an external document.  The note contains an `<extref altrender="online_media">` inside of `<p>` tags, with the extref's `xlink:href` and `xlink:title` attributes populated from the external document record.  External documents are not exported by ASpace by default.

_Rights Statements_

11. <a name="eleven"></a>Within `<archdesc>`, exports `<userestrict>` holding a `<head>`, `<note>`, and `<list><item><date/></item></list>` matching a resource-level rights statement.  Rights statements are not exported by ASpace by default.
12. <a name="twelve"></a>Within `<c>`, exports `<userestrict>` holding a `<head>`, `<note>`, and `<list><item><date/></item></list>` matching an archival object-level rights statement.  Rights statements are not exported by ASpace by default.

| Line         | ASpace Default (simplified example)                                | SI Override (simplified example)                                      |
| ------------ | ------------------------------------------------------------------ | --------------------------------------------------------------------- |
| [1](#one)    | `<persname source="display_name['source']">`                       | `<persname source="primary_identifier['source']">`                    |
| [2](#two)    | `<persname authfilenumber="display_name['authority_id']">`         | `<persname authfilenumber="primary_identifier['record_identifier']">` |
| [3](#three)  | `<extent altrender="materialtype spaceoccupied">1 Sheets</extent>` | `<extent type="Sheets">1 Sheets</extent>`                             |
| [4](#four)   | `<geogname>Cultural Context Term</geogname>`                       | `<subject>Cultural Context Term</subject>`                            |
| [5](#five)   | none                                                               | `<subjec>Temporal term</subject>`                                     |
| [6](#six)    | `<subject>`                                                        | `<subject altrender="topical">`                                       |
| [7](#seven)  | `<persname source="display_name['source']">`                       | `<persname source="primary_identifier['source']">`                    |
| [8](#eight)  | `<persname authfilenumber="display_name['authority_id']">`         | `<persname authfilenumber="primary_identifier['record_identifier']">` |
| [9](#nine)   | none                                                               | `<note altrender="external_documents" label="See Also"><p><extref altrender="online_media" xlink:href="location" xlink:title="Title">Title</extref></p></note>` |
| [10](#ten)   | none                                                               | `<note altrender="external_documents" label="See Also"><p><extref altrender="online_media" xlink:href="location" xlink:title="Title">Title</extref></p></note>` |
| [11](#eleven)| none                                                               | `<userestrict id="aspace_[identifier]" type="[rights_type]"><head>Rights Statement</head><note type="[note_type]"><p>[note_content]</p></note><list><item><date normal="[start_date]" type="start" /></item></list></userestrict>` |
| [12](#twelve)| none                                                               | `<userestrict id="aspace_[identifier]" type="[rights_type]"><head>Rights Statement</head><note type="[note_type]"><p>[note_content]</p></note><list><item><date normal="[start_date]" type="start" /></item></list></userestrict>` |

## Tests

Run the backend tests via: 

```
./build/run backend:test -Dspec="../../plugins/lassb-ead-exporter"
```
