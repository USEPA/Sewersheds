**Current Release: Version 1.1 (Updated January 26, 2026)**

## Version 1.1 Release Notes

Version 1.1 of the Sewershed dataset was released on January 26th, 2026.

- 21 new utility sourced sewersheds were included

**Current breakdown of sourced vs. modeled sewersheds**

3,219 sourced, 13,864 modeled (18.8% sourced).

We have added a table to this folder named 'sources.csv', which tracks the sewersheds that have been added into the dataset and how the data was obtained.

'sources.csv' metadata

# Add a markdown table with two columns aligned to the left, with column labels: 'column' and 'description' with 5 rows
| column          | description                                                                                   |
|-----------------|-----------------------------------------------------------------------------------------------|
| CWNS_ID    | Unique identifier for each POTW (sewershed) |
| POTW_Name | The POTW name as listed in the CWNS |
| Source_Name | Name of the data source |
| How_Obtained | How the data was obtained (public download / feedback portal / email communication) |
| Source_Path | URL (if applicable) that data was retrieved from |
| Feature_Type | The type of data obtained, for example a service area polygon or sewer lines |
| Method | The method used to derive the service area |
| Date_Obtained | The date EPA obtained the data |
| Version_Added | The first version that the data was added to the sewershed dataset |