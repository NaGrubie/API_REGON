# API REGON GUS Data Extraction Tool

## Overview
This R script provides functionality for connecting to the BIR (Business Intelligence Reporting) API of Poland's Central Statistical Office (GUS) and extracting full reports for business entities based on their REGON numbers. The tool enables both individual and batch processing of REGON numbers.

## Features
- Authentication with the GUS REGON API using API key
- Session management (login/logout)
- Retrieving detailed reports for business entities
- Parsing XML responses into usable data frames
- Batch processing of multiple REGON numbers from a text file
- Exporting results to delimited text files

## Requirements
The script requires the following R packages:
- stringr
- readr
- httr2
- xml2

You can install them using:
```R
install.packages(c("stringr", "readr", "httr2", "xml2"))
```

## Usage

### Authentication
Before making any API calls, you need to authenticate with the GUS API:
```R
# Set your API key
USER_KEY <- "your_api_key_here"

# Login to get session ID
sid <- zaloguj()
```

### Individual REGON Query
To extract data for a single REGON number:
```R
# Get full report for a specific REGON
result_regon <- get_full_report_result("273650781", "BIR11OsPrawna", user_key = USER_KEY, sid = sid)
response_text <- resp_body_string(result_regon)

# Parse the result into a data frame
dane_df <- parse_full_report(response_text)

# Save the data to a file
write_delim(dane_df, "output_file.txt", delim="|")
```

### Batch Processing
To process multiple REGON numbers from a file:
```R
# Process a file containing REGON numbers (one per line)
process_regon_file("path_to_regon_file.txt", "output_file.txt", user_key = USER_KEY, sid = sid)
```

### Ending a Session
Always logout from the API when you're done:
```R
wyloguj(sid)
```

## Report Types
The default report type is "BIR11OsPrawna" for legal entities. The API supports various report types depending on the entity type:

| Type | SILOSD | Report Name | Description |
|------|--------|-------------|-------------|
| F | 1/2/3 | BIR11OsFizycznaDaneOgolne | General data for natural persons across all business activities |
| F | 1/2/3 | BIR12OsFizycznaDaneOgolne | Same functionality as above, no significant differences |
| F | 1 | BIR11OsFizycznaDzialalnoscCeidg | Data about activity registered in CEIDG, including business address |
| F | 1 | BIR12OsFizycznaDzialalnoscCeidg | Enhanced functionality with LENGTH(fiz_adSiedzNumeroLokalu)=20 |
| F | 2 | BIR11OsFizycznaDzialalnoscRolnicza | Data about agricultural activity, including address |
| F | 2 | BIR12OsFizycznaDzialalnoscRolnicza | Enhanced functionality with LENGTH(fiz_adSiedzNumeroLokalu)=20 |
| F | 3 | BIR11OsFizycznaDzialalnoscPozostala | Data about other activities not in CEIDG or agriculture |
| F | 3 | BIR12OsFizycznaDzialalnoscPozostala | Enhanced functionality with LENGTH(fiz_adSiedzNumeroLokalu)=20 |
| F | 4 | BIR11OsFizycznaDzialalnoscSkreslonaDo20141108 | Data about activity deleted from REGON before 2014-11-08 |
| F | 4 | BIR12OsFizycznaDzialalnoscSkreslonaDo20141108 | Same functionality as above, no significant differences |
| F | 1/2/3 | BIR11OsFizycznaPkd | List of PKD codes for natural person |
| F | 1/2/3 | BIR12OsFizycznaPkd | Enhanced functionality with additional XML element |
| F | 1/2/3 | BIR11OsFizycznaListaJednLokalnych | List of local units registered for a natural person |
| F | 1/2/3 | BIR12OsFizycznaListaJednLokalnych | Enhanced functionality with LENGTH(fiz_adSiedzNumeroLokalu)=20 |
| LF | 1/2/3 | BIR11JednLokalnaOsFizycznej | Data of local unit of natural person |
| LF | 1/2/3 | BIR12JednLokalnaOsFizycznej | Enhanced functionality with LENGTH(lokfiz_adSiedzNumeroLokalu)=20 |
| LF | 1/2/3 | BIR11JednLokalnaOsFizycznejPkd | List of PKD codes for local unit of natural person |
| LF | 1/2/3 | BIR12JednLokalnaOsFizycznejPkd | Enhanced functionality with additional XML element |

Legend:
- Type F = Natural person
- Type LF = Local unit of a natural person
- SILOSD = Business activity type code (1 = CEIDG, 2 = Agriculture, 3 = Other, 4 = Deleted activities)

This table shows the report types for natural persons (F) and their local units (LF). Each report serves a specific purpose such as getting general information, specific activity data, or PKD codes.

## Current Limitations and Roadmap

**DISCLAIMER:** This tool currently only supports the "DanePobierzPelnyRaport" method for retrieving full entity reports. The "DaneSzukajPodmioty" method for searching entities will be added in a future update.

The current implementation focuses on retrieving detailed reports for entities when you already know their REGON numbers. Entity search functionality is planned for an upcoming release.

## Troubleshooting
- The script includes extensive error handling to deal with API response parsing issues
- Debug mode in the `zaloguj()` function can be enabled to see detailed API responses
- If parsing fails, the script will attempt alternative extraction methods

## Notes
- This script is configured to use the test environment of the REGON API (wyszukiwarkaregontest.stat.gov.pl)
- For production use, update the URL to the production environment
- Default API key in the code is a dummy value - replace with your actual key
- The script includes 1-second delay between requests during batch processing to avoid overwhelming the API

## File Format
The output is saved as a pipe-delimited text file that can be easily imported into Excel or other analysis tools.

---
*Last updated: March 2025*
