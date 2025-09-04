# gov_opps_api
R code for using the grants.gov APIs

## Introduction
These functions allow you to search for and retrieve US Government funding opportunities from grants.gov using the grants.gov REST APIs (https://grants.gov/api) in the R programming language. At the moment, documentation of these APIs is extremely limited, so many input and output parameters for these endpoints are not currently known. These functions are also still in active development, so there are still a few bugs that need to be worked out. 

The general workflow is as follows. You first create and save a search query using the `create_query()` function. You then run the `search_opps()` function to retrieve limited information about the documents that match your query, and then you use the `fetch_opps()` function to retrieve the full set of available information for each document you want to retrieve. The `fetch_opps()` function returns over 150 fields for each document, many of them containing duplicative information, so the `simplify_opps()` function attempts to simplify the resulting data frame into a more manageable set of columns based on the display information for each record in the grants.gov web interface. 

These functions use functions from the httr and jsonlite packages, as well as an old function from plyr. Currently, they have only been tested on opportunity notices from the NIH, though they should also work for other agencies. 

## Vignette
In this vignette, we’ll retrieve all currently forecasted notices that NICHD has currently sponsored or participated in.
First, we load the functions with `source()`.
```r
source("gov_opps_api.r")
```

Next, we save the query we want to run with `create_query()`.
```r
mq <- create_query(oppStatuses = "forecasted", cfda = "93.865")
```

We then run the search and retrieve basic information for the results with` search_opps()`. The function will automatically make additional requests until it retrieves all available search results or until it reaches the number set in the optional max_results argument. 
```r
the_opps <- search_opps(mq, max_results = 100)
```

Finally, we fetch the full records of the search results with `fetch_opps()` and simplify the resulting data frame using `simplify_opps()`. 
```r
opp_info <- fetch_opps(the_opps$id)
opp_info_simple <- simplify_opps(opp_info, "forecast")
```

## Query parameters
The `create_query()` function has a series of somewhat cryptically named arguments that correspond to search options in the search2 REST API endpoint. Here are some more details about what each argument is and what the available options are. 
*	rows: the number of records to retrieve per request. The current default is 25.
*	keyword: a free text search that presumably searches across multiple fields in the record. What fields are searched is not currently specified.
*	oppNum: The opportunity number or (presumably) numbers you want to search for. I don’t currently know how to search for more than one at a time.
*	eligibilities: what kinds of entities are eligible to apply. Options include county governments, private institutions of higher education, small businesses, etc.
*	agencies: top-level agencies like NSF, HHS, or NIH. To search for NIH, use “HHS-NIH11”.
*	oppStatuses: Current status of the opportunity. Options are ‘forecasted’, ‘posted’, ‘closed’, and ‘archived’. You can search for multiple options using the syntax ‘closed|archived’. Opportunities that are ‘posted’ are currently open for applications, while those that are ‘closed’ and ‘archived’ are not.
*	aln: Government-wide assistance listing number of the opportunity. For the NIH, it acts as the equivalent of the sponsoring Institute(s) or Center(s). It appears identical to the cfda. aln/cfda numbers are searchable at https://sam.gov/search/. The API currently ignores this parameter, so use the cfda instead.
*	fundingCategories: Government-wide funding category of the opportunity. Options include ‘Health’, ‘Education’, ‘Environment, Food and Nutrition’, ‘Income Security and Social Services’, and ‘Transportation’. 
*	fundingInstruments: The type of funding mechanism solicited by the opportunity. Options are ‘grant’, ‘cooperative agreement’, ‘procurement contract’, and ‘other’.
*	startRecordNum: The starting number of the record you want to retrieve. Numbering for this API starts at 0, which is the default value.
*	cfda: Assistance listing number from the old Catalog of Federal Domestic Assistance. It appears identical to the aln and acts (for the NIH) as an IC search. Use this instead of the aln, because the API actually uses this as a filter. Options include ’93.866’ for NIA, ’93.865’ for NICHD, ’93.867’ for NEI, etc. Some ICs, like NHLBI and NCI, have multiple cfda numbers. aln/cfda numbers are searchable at https://sam.gov/search/.
*	dateRangeOptions: The API response lists this as a search option, but it isn’t documented, and I can’t figure out what values the API will accept or what the corresponding date ranges are. 
*	sortBy: Presumably the field or fields you wish to sort the results by, but there is no documentation about what they are or how to use them.
