#' Import data from locally managed AQ networks in England.
#'
#' Functions for importing air pollution data from locally managed English air
#' quality networks. These data are not associated with the AURN so may not have
#' the same level of quality control applied to them as data made available by,
#' for example, [importAURN()].
#'
#' @inheritSection importAURN Importing UK Air Pollution Data
#'
#' @param data_type The data type averaging period. These include:
#'
#'   \itemize{
#'   \item{"hourly"}{ Default is to return hourly data.}
#'   \item{"daily"}{ Daily average data.}
#'   \item{"monthly"}{ Monthly average
#'   data with data capture information for the whole network.}
#'   \item{"annual"}{ Annual average data with data capture information for the
#'   whole network.}
#'   \item{"15_min"}{ To import 15-minute average SO2
#'   concentrations.}
#'   \item{"8_hour"}{ To import 8-hour rolling mean
#'   concentrations for O3 and CO.}
#'   \item{"24_hour"}{ To import 24-hour rolling
#'   mean concentrations for particulates.}
#'   \item{"daily_max_8"}{ To import maximum daily rolling 8-hour maximum for O3 and CO.}
#'   }
#' @inheritParams importAURN
#' @param site Site code of the site to import e.g. \dQuote{ad1} is Adur,
#'   Shoreham-by-Sea. Several sites can be imported with \code{site = c("ad1",
#'   "ci1")} --- to import Adur and A27 Chichester Bypass, for example.
#' @family import functions
#' @export
importLocal <-
  function(site = "ad1",
           year = 2018,
           data_type = "hourly",
           pollutant = "all",
           meta = FALSE,
           to_narrow = FALSE,
           progress = TRUE) {
    # Warn about QC/QA every 8 hrs
    cli::cli_warn(
      c("i" = "This data is associated with locally managed air quality network sites in England.",
        "!" = "These sites are not part of the AURN national network, and therefore may not have the same level of quality control applied to them."),
      .frequency = "regularly",
      .frequency_id = "lmam"
    )

    if (data_type %in% c("annual", "monthly")) {
      files <-
        paste0(
          "https://uk-air.defra.gov.uk/openair/LMAM/R_data/summary_",
          data_type,
          "_LMAM_",
          year,
          ".rds"
        )

      # read data
      if (progress)
        progress <- "Importing Statistics"
      aq_data <- purrr::map(
        files,
        readSummaryData,
        data_type = data_type,
        to_narrow = to_narrow,
        hc = FALSE,
        .progress = progress
      ) %>%
        purrr::list_rbind()

      # filtering
      aq_data <-
        filter_annual_stats(
          aq_data,
          missing(site),
          site = site,
          pollutant = pollutant,
          to_narrow = to_narrow
        )

      # add meta data?
      if (meta) {
        aq_data <- add_meta(source = "local", aq_data)
      }
    } else {
      # force uppercase
      site <- toupper(site)

      # get pcodes for file paths
      pcodes <-
        importMeta("local", all = TRUE) %>%
        dplyr::distinct(.data$site, .keep_all = TRUE) %>%
        select("code", "pcode")

      # get sites and pcodes
      site_pcodes <-
        data.frame(code = site) %>%
        merge(pcodes)

      # map over sites and pcodes
      # needed because sites may come from different pcodes
      aq_data <-
        purrr::map2(
          .x = site_pcodes$code,
          .y = site_pcodes$pcode,
          .f = ~ importUKAQ(
            site = .x,
            year = year,
            data_type,
            pollutant = pollutant,
            ratified = FALSE,
            to_narrow = to_narrow,
            source = "local",
            lmam_subfolder = .y,
            progress = progress
          )
        ) %>%
        purrr::list_rbind()

      if (meta) {
        aq_data <- add_meta(source = "local", aq_data)
      }
    }

    return(as_tibble(aq_data))
  }
