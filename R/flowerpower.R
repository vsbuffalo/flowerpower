# flowerpower.R
##' @importFrom R6 R6Class

# suppress warnings; TODO: not optimal
options(lubridate.verbose = FALSE)

FPDEBUG <- FALSE

stop_for_status <- function(x) {
  if (FPDEBUG)
    if (!httr:::successful(x)) {
      print(x)
      browser()
    }
  httr:::stop_for_status(x)
}

# URL stuff
FPAPI_ROOT <- "https://apiflowerpower.parrot.com/"
fpurl <- function(path) paste0(FPAPI_ROOT, path)
FPAPI_GETLOCS <- fpurl("sensor_data/v3/sync")
FPAPI_GETSAMPS <- fpurl("sensor_data/v2/sample/location/")
FPAPI_AUTH <- fpurl("user/v1/authenticate")

#' Internal function to create data ranges (since max date span is 10 days)
date_ranges <- function(from, to=now(), interval=days(9)) {
  n <- ceiling(as.period(to - from)/interval)
  out <- vector('list', n)
  last <- from
  for (i in seq_len(n)) {
    out[[i]] <- c(last, last + interval)
    last <- last + interval
  }
  out
}

#' All internal methods are in R6, API funs in S3
flowerpower_factory <- R6::R6Class(
  "flowerpower",
   public=list(
     keys=NULL,
     auth_header=NULL,
     token=NULL,
     locations=list(),
     last_sync=NULL,
     auth=function() {
       auth_query <- c(list(grant_type='password'), self$keys)
       r <- GET(FPAPI_AUTH, query=auth_query)
       stop_for_status(r)
       self$token <<- content(r)$access_token
       authkey <- sprintf("Bearer %s", self$token)
       self$auth_header <<- add_headers(Authorization=authkey)
       self
     },
     initialize=function(user, pass, client_id, client_secret) {
       self$keys <<- list(username=user,
                            password=pass,
                            client_id=client_id,
                            client_secret=client_secret)
       self$auth()
    },
     is_auth=function() {
       return(!is.null(self$token))
     },
     sync=function() {
       # server sync request; for location other data
       r <- GET(FPAPI_GETLOCS, self$auth_header)
       stop_for_status(r)
       cont <- content(r)
       self$last_sync <<- cont
       cont
     },
     get_data=function(location, from=NULL, to=NULL) {
       # NOTE: returns list of each time range (lower-level fun)
       if (!is.null(from) || !is.null(to)) stop("not implemented")
       assigned_data <- ymd_hms(get_locations(self, location)$plant_assigned_date)
       rngs <- date_ranges(assigned_data, interval=days(10))
       do.call(c, lapply(rngs, function(rng) {
         rng <- as.character(rng)
         qry <- list(from_datetime_utc=rng[1], to_datetime_utc=rng[2])
         locurl <- paste0(FPAPI_GETSAMPS, location)
         r <- GET(locurl, query=qry, self$auth_header)
         stop_for_status(r)
         content(r)
       }))
     },
     check_sync=function() {
       if (is.null(self$last_sync))
         self$sync()
     }
    ))

#' @export
flowerpower <- function(user, pass, client_id, client_secret) {
  flowerpower_factory$new(user, pass, client_id, client_secret)
}

#' Get all sensor locations
#'
#' @param obj a flowerpower object
#' @param location a location identifier
#'
#' @export
get_locations <- function(obj, location=NULL) {
  UseMethod("get_locations")
}

#' Get all sensor locations
#'
#' @param obj a flowerpower object
#' @param location a location identifier
#'
#' @export
get_locations.flowerpower <- function(obj, location=NULL) {
  obj$check_sync()
  ignore_cols <- c("images", "display_order", "avatar_url",
                   "ignore_fertilizer_alert",
                   "ignore_light_alert",
                   "ignore_moisture_alert",
                   "ignore_temperature_alert")
  tmp <- do.call(rbind, lapply(obj$last_sync$locations, function(x) {
    data.frame(x[setdiff(names(x), ignore_cols)], stringsAsFactors=FALSE)
  }))
  if (!is.null(location))
    return(tmp[tmp$location_identifier == location, ])
  tmp$plant_assigned_data <- ymd_hms(tmp$plant_assigned_date)
  tmp
}

#' Get data samples.
#'
#' @param obj a flowerpower object
#' @param location a location identifier
#'
#' @export
get_samples <- function(obj, location) {
  UseMethod("get_samples")
}

#' Get data samples.
#'
#' @param obj a flowerpower object
#' @param location a location identifier
#'
#' @export
get_samples.flowerpower <- function(obj, location) {
  obj$check_sync()
  dt <- obj$get_data(location)
  tmp <- as.data.frame(do.call(rbind, dt$samples), stringsAsFactors=FALSE)
  # bit hacky; TODO
  out <- data.frame(lapply(tmp, unlist), stringsAsFactors=FALSE)
  out$capture_ts <- ymd_hms(out$capture_ts)
  out
}
