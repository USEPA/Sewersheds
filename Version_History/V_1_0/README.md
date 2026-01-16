## Version 1.0 Release Notes

Release Date: September 5, 2025

### File Information

There are three files contained within this folder:

'Version_1_0.gpkg' contains the polygon files for the sewersheds. The coordinate system is WGS 84.

Column Descriptions:


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

_________________________________________________

'CWNS_NPDES_Crosswalk.csv' is a text file that includes the information needed to join data realted to the National Pollutant Discharge Elimination System (NPDES).
Users should note that not all treatment plants have a NPDES permit. Many treatment plants do not discharge into U.S. waters. For more information on NPDES, refer to: [U.S. EPA NPDES](https://www.epa.gov/npdes).

| Column          | Description                                      |
|:----------------|:-------------------------------------------------|
| CWNS_ID    | Unique identifier for each sewershed, corresponding to the 2022 Clean Watershed Needs Survey |
| FACILITY_ID | Facility ID associated with the treatment plant (sourced from CWNS) |
|Permit_Number | NPDES permit number as reported in the 2022 CWNS |

_________________________________________________

'Discharge_Links.csv' is a table that includes all facilities that reported any discharge to a separate facility in the 2022 CWNS. This is a subset of the complete 'DISCHARGES' table available in the 2022 CWNS data set.

| Column          | Description                                      |
|:----------------|:-------------------------------------------------|
| CWNS_ID    | Unique identifier for each sewershed, corresponding to the 2022 Clean Watershed Needs Survey |
| FACILITY_ID | Facility ID associated with the treatment plant (sourced from CWNS) |
| Discharge_Type | All values in this field are 'Discharge to Another Facility'. For more discharge types, refer to complete CWNS data |
| Discharge_Pct | The percent of discharge sent to another facility (as reported in the 2022 CWNS) |
| Discharges_To | The CWNS ID of the facility the discahrge is sent to |

## Looking for more CWNS data?

The complete CWNS data set can be downloaded from the [EPA CWNS Data Download Page](https://sdwis.epa.gov/ords/sfdw_pub/r/sfdw/cwns_pub/data-download?session=8170507243772)



