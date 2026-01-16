## Version 1.0 Release Notes

Release Date: September 5, 2025

### File Information

There are three files contained within this folder:

'Version_1_0.gpkg' contains the polygon files for the sewersheds. The coordinate system is WGS 84.

Column Descriptions:

Markdown Table with two columns: 'Column' and 'Description', centered headings, left-aligned text
| Column          | Description                                      |
|:----------------|:-------------------------------------------------|
| CWNS_ID    | Unique identifier for each sewershed, corresponding to the 2022 Clean Watershed Needs Survey |
| Method | Either 'Modeled' or 'Sourced' denoting whether the sewershed was produced by the EPA model or obtained from another source such as state or utility data |
| Min_Prob | The lowest hexagon probability included in a modeled sewershed |
| Mean_Prob | The average hexagon probability included in a modeled sewershed |
| Pop_2020 | The Estimated 2020 census population of the sewershed |
| Buildings | The count of microsoft building footprints within the sewershed |
| FACILITY_NAME | The name of the treatment facility which serves as the endpoint for the sewershed as reported in the CWNS |
| STATE_CODE | The 2 character state abbreviation |
| CITY | The city where the endpoint facility is located as reported in the CWNS |
| RESIDENTIAL_POP_2022 | The residential population served by the treatment facility (**not** including populations served by upstream facilities that discharge to it) as reported in the CWNS |
| TOTAL_RES_POPULATION_2022 | The residential population served by the treatment facility (**including** populations served by upstream facilities that discharge to it) as reported in the CWNS |
| geom | The polygon geometry for the sewershed |
