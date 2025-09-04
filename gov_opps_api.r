# API documentation at https://grants.gov/api/
## NIH Guide going away: https://grants.nih.gov/grants/guide/notice-files/NOT-OD-25-143.html

create_query <- function(keyword = "", oppNum = "", eligibilities = "", agencies = "", oppStatuses = "", aln = "", fundingCategories = "", fundingInstruments = "", rows = 25, startRecordNum = 0, cfda = "", sortBy = "") {
	the_q <- list(
		rows = jsonlite::unbox(rows), ## number of results per request
		keyword = jsonlite::unbox(keyword), ## text search box
		oppNum = jsonlite::unbox(oppNum), ## opportunity number
		eligibilities = jsonlite::unbox(eligibilities), ## what kind of entity is eligible to apply (i.e. county givernments, private institutions of higher education, etc)
		agencies = jsonlite::unbox(agencies), ## top level agencies like HHS; NIH = HHS-NIH11
		oppStatuses = jsonlite::unbox(oppStatuses), ## forecasted, posted, closed, archived; can search multiple by doing forecasted|posted
			## forecasted = forecast, posted = currently accepting applications, archived = application period closed
		aln = jsonlite::unbox(aln), ## assistance listing numbers? appears equivalent to cfda
		fundingCategories = jsonlite::unbox(fundingCategories), ## funding activity categories: Health, Education, Environment, Food and Nutrition, Income Secutiry and Social Services
		fundingInstruments = jsonlite::unbox(fundingInstruments), ## grant, cooperative agreement, procurement contract, other
		startRecordNum = jsonlite::unbox(startRecordNum), 
		cfda = jsonlite::unbox(cfda), ## equivalent of IC search; NICHD is 93.865,
		#dateRangeOptions = jsonlite::unbox(dateRangeOptions), search seems to be ignoring this
		sortBy = jsonlite::unbox(sortBy) ## I have no idea what the available sorting options are or what they're called
		## there have got to be date range options available somewhere
	)
	the_q <- the_q[the_q != ""]
	the_q <- jsonlite::toJSON(the_q)
	return(the_q)
}

search_opps <- function(mq, start_number = 0, max_results = Inf) {
	theData <- list()
	the_response <- httr::POST("https://api.grants.gov/v1/api/search2", body = mq)
	the_response <- httr::content(the_response, as = "text")
	theData[[1]] <- jsonlite::fromJSON(the_response)
	total_results <- theData[[1]]$data$hitCount
	if (total_results == 0) {
		message("No results found")
		return(NA)
	}
	results_retrieved <- nrow(theData[[1]]$data$oppHits)
	pages_needed <- ceiling(total_results / results_retrieved)
	max_pages_needed <- ceiling(max_results / results_retrieved)
	if (max_pages_needed < pages_needed) {
		pages_needed <- max_pages_needed
	}
	theData[[1]] <- theData[[1]]$data$oppHits
	message(paste("Found", total_results, "results.  Retrieving", pages_needed, "total batches"))
	if (pages_needed > 1) {
		for (i in 2:pages_needed) {
			Sys.sleep(1)
			last_start <- start_number
			start_number <- start_number + results_retrieved
			mq <- gsub(paste0("\"startRecordNum\":", last_start), paste0("\"startRecordNum\":", start_number), mq)
			the_response <- httr::POST("https://api.grants.gov/v1/api/search2", body = mq)
			the_response <- httr::content(the_response, as = "text")
			theData[[i]] <- jsonlite::fromJSON(the_response)
			results_retrieved <- nrow(theData[[i]]$data$oppHits)
			theData[[i]] <- theData[[i]]$data$oppHits
		}
		theData <- do.call(rbind, theData)
	}
	else if (pages_needed == 1) {
		theData <- theData[[1]]
	}
	theData$cfdaList <- sapply(theData$cfdaList, paste, collapse = ";")
	return(theData)
}

fetch_opps <- function(the_opp_ids) {
	the_pages <- list()
	for (i in 1:length(the_opp_ids)) {
		mq <- paste0("{\"opportunityId\":", the_opp_ids[i], "}")
		the_response <- httr::POST("https://api.grants.gov/v1/api/fetchOpportunity", body = mq)
		the_response <- httr::content(the_response, as = "text")
		the_response <- jsonlite::fromJSON(the_response)
		the_response <- the_response$data
		the_response[sapply(the_response, length) == 0] <- NA
		the_response <- as.data.frame(t(unlist(the_response)))
		dup_cols <- colnames(the_response)[grepl("\\d$", colnames(the_response))]
		dup_cols <- unique(gsub("\\d{1,2}$", "", dup_cols)) ## could there be over 100 duplicate columns?
		new_cols <- sapply(1:length(dup_cols), function(x) paste(unique(unlist(unname(the_response[,grepl(dup_cols[x], colnames(the_response))]))), collapse = ";"))
		names(new_cols) <- dup_cols
		new_cols <- as.data.frame(t(new_cols))
		the_response <- cbind(the_response, new_cols)
		the_response <- the_response[,grepl("\\d$", colnames(the_response)) == FALSE]
		the_pages[[i]] <- the_response
		Sys.sleep(1)
	}
	the_pages <- do.call(plyr::rbind.fill, the_pages) ## need to work on this
	return(the_pages)
} ## note: still getting number columns in the result; i.e. opportunityHistoryDetails.synopsis.fundingInstruments.id.1

simplify_opps <- function(the_opps, opp_type) {
	if (opp_type %in% c("synopsis", "posted")) {
	newDF <- the_opps[,c(
		"id",
		"docType",
		"opportunityNumber",
		"opportunityTitle",
		"opportunityCategory.description",
		paste0(opp_type, ".fundingInstruments.description"),
		paste0(opp_type, ".fundingActivityCategories.description"),
		"cfdas.cfdaNumber",
		"cfdas.programTitle",
		paste0(opp_type, ".costSharing"),
		paste0(opp_type, ".version"),
		paste0(opp_type, ".postingDate"),
		paste0(opp_type, ".lastUpdatedDate"),
		"originalDueDate",
		"opportunityPkgs.openingDate", 
		"opportunityPkgs.closingDate", 
		paste0(opp_type, ".archiveDate"),
		paste0(opp_type, ".awardFloor"),
		paste0(opp_type, ".awardCeiling"),
		paste0(opp_type, ".applicantTypes.description"),
		paste0(opp_type, ".applicantEligibilityDesc"),
		"agencyDetails.agencyName",
		paste0(opp_type, ".synopsisDesc"),
		paste0(opp_type, ".fundingDescLinkUrl"),
		paste0(opp_type, ".agencyContactDesc"),
		paste0(opp_type, ".agencyContactEmail"),
		paste0(opp_type, ".agencyContactEmailDesc"),
		"relatedOpps"
	)
	]
	}
	else if (opp_type == "archived") {
		newDF <- the_opps[,c(
		"id",
		"docType",
		"opportunityNumber",
		"opportunityTitle",
		"opportunityCategory.description",
		"synopsis.fundingInstruments.description",
		"synopsis.fundingActivityCategories.description",
		"cfdas.cfdaNumber",
		"cfdas.programTitle",
		"synopsis.costSharing",
		"synopsis.version",
		"synopsis.postingDate",
		"synopsis.lastUpdatedDate",
		"originalDueDate",
		"closedOpportunityPkgs.openingDate", 
		"closedOpportunityPkgs.closingDate", 
		"synopsis.archiveDate",
		"synopsis.awardFloor",
		"synopsis.awardCeiling",
		"synopsis.applicantTypes.description",
		"synopsis.applicantEligibilityDesc",
		"agencyDetails.agencyName",
		"synopsis.synopsisDesc",
		"synopsis.fundingDescLinkUrl",
		"synopsis.agencyContactDesc",
		"synopsis.agencyContactEmail",
		"synopsis.agencyContactEmailDesc",
		"relatedOpps"
	)
	]
	}
	else if (opp_type == "forecast") {
	newDF <- the_opps[,c(
		"id",
		"docType",
		"opportunityNumber",
		"opportunityTitle",
		"opportunityCategory.description",
		paste0(opp_type, ".fundingInstruments.description"),
		paste0(opp_type, ".fundingActivityCategories.description"),
		"cfdas.cfdaNumber",
		"cfdas.programTitle",
		paste0(opp_type, ".costSharing"),
		paste0(opp_type, ".version"),
		paste0(opp_type, ".postingDate"),
		paste0(opp_type, ".lastUpdatedDate"),
		paste0(opp_type, ".applicantTypes.description"),
		paste0(opp_type, ".applicantEligibilityDesc"),
		"agencyDetails.agencyName",
		"forecast.forecastDesc",
		"forecast.estSynopsisPostingDateStr",
		"forecast.estApplicationResponseDateStr",
		"forecast.estAwardDateStr",
		"forecast.estProjectStartDateStr",
		paste0(opp_type, ".agencyContactEmail"),
		paste0(opp_type, ".agencyContactEmailDesc"),
		"relatedOpps"
	)
	]
	}
	else {
	stop("Invalid opp_type. Valid values are 'forecast', 'posted', 'synopsis', and 'archived'")
	}
	return(newDF)
}
