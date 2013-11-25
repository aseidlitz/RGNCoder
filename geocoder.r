# Geonames geocoding interface (alpha)
# Resolves addresses to lat and lon pairs (plus extra info) using GeoNames Webservices
# Very early alpha code. Use at your own risk
#
# Based on ggmap::geocode code by David Kahle
# Geonames API Terms of Service : http://www.geonames.org/about.html
# Use of Geonames Geocoding requires free account: http://www.geonames.org/login

### Sample usage:
# if(geocode_refresh) #  || !ObjExists(loc)) 
# {       
#   writeLines("Geocoding...")
#   loc <- count(rs[ , c("city","state","country")]) # calculate frequency (number of respondents from a city)  
#   geo.data <- geocoder(loc)
#   geo <- geo.data$results   
#   geo <- rename(geo, c("city"="city.resolved","state"="state.resolved","country"="country.resolved"))  
#   geo <- rename(geo, c("source_city"="city","source_state"="state","source_country"="country"))
#   loc <- join(loc, geo, match="first", by=c("city","state","country"))
#   save(loc, geo, geo.data, file="geo_locations.RData")
# } else {
#   writeLines("Skipping Geocoding, loading saved data...")
#   load("geo_locations.RData")
# }

# TODO: Make sure location.collector doesn't override global df with the same name

library(RJSONIO)

GNUSER = "enter_your_geonames_username" # should probably go in the calling script
FUZZINESS = 0.7  # default: fuzzy=0.7 - good detection, 0.6 - slightly worse, 0.5 very bad detection
# BUT sometimes fuzziness prevents from getting an obvious answer

geocoder <- function(src) 
{  
  start_time <- proc.time()
  errors <- 0
  success <- 0
  
  # Create an empty dataframe with the same strcucture as returned by geocode_gn()
  location.collector <- geocode_gn('Vancouver, BC')
  location.collector <- location.collector[-1,]
  # and a frame for errors, removing original factor levels
  location.errors <- src[0,]
  j <- sapply(location.errors, is.factor)
  location.errors[j] <- lapply(location.errors[j],as.character) 
  
  # TODO: verify that source df hs appropriate columns
  
  for(i in 1:nrow(src)) { 
    s <- src[i,]
  
    writeLines(paste('\nResolving[', i ,']: ', ((success)*100)%/%(i-1), '% success rate', sep=""))
    writeLines(paste(s$city, s$state, s$country, sep=", " ), sep=" ")
    
    r <- geocode_gn(city=s$city, state=s$state, country=s$country, fuzzy=FUZZINESS) #, 
                    #zip=s$zip, address1=s$address1, address2=s$address2) 
   
    
    if (is.na(r)) {
      errors <- errors + 1
      if (ncol(s)==ncol(location.errors))
      {  
        # this doesn't work because you can't pass it back
        location.errors <- rbind(location.errors,s) 
      }
    } else 
    {
      success <- success + 1
      if (ncol(r)==ncol(location.collector))
      {  
        location.collector <- rbind(location.collector,r)  
      }  
    }
    
    # Debug delay
    # Sys.sleep(2)
    
    # writeLines(' --> ',sep=" ")
    # cat(length(r$toponymName))
    
    if(i%%10 == 0) save(location.collector,file="Data/location.collector.RData")
    
  }
  
  writeLines(as.character(Sys.time()))
  writeLines(paste0('Processed ',i,' addresses ', (success*100)%/%i, '% success rate'))
  writeLines(paste0('       Found: ', success,' Failed: ', errors ))                 
  proc.time() - start_time
  
  # ugly hack to preserve errors
  save(location.errors, file="Data/location.errors.RData")
  
  return(list("results"=location.collector, "errors"=location.errors))

}


geocode_gn <- function (city, state=NA, country=NA, zip=NA, address1=NA, address2=NA, api_key= GNUSER, fuzzy=FUZZINESS, service_retries = 3, retry_delay = 2, verbose = T, debug = F) 
{
  service_limit_sleep <- 60*60+300 # 1 hour 5 min
  
  m <- "Use of Geonames Geocoding requires free account: http://www.geonames.org/login" 
  if(nchar(api_key) == 0){
    stop(m, call.= F)
  }
  
  city.org <- city
  state.org <- state
  country.org <- country
  zip.org <- zip
  address1 <- address1
  address2 <- address2
  
  if(!is.null(city) && is.na(city)) city <- NULL
  if(!is.null(state) && is.na(state)) state <- NULL
  if(!is.null(country) && is.na(country)) country <- NULL
  if(!is.null(zip) && is.na(zip)) zip <- NULL
  if(!is.null(address1) && is.na(address1)) address1 <- NULL
  if(!is.null(address2) && is.na(address2)) address2 <- NULL
  
#   city <- gsub(" ", "+", iconv(as.character(city),to='ASCII//TRANSLIT'))
#   state <- gsub(" ", "+", iconv(as.character(state),to='ASCII//TRANSLIT'))
#   country <- gsub(" ", "+", iconv(as.character(country),to='ASCII//TRANSLIT'))
#    city <- gsub(" ", "+", as.character(city))
#    state <- gsub(" ", "+", as.character(state))
#    country <- gsub(" ", "+", as.character(country))
  
  base_url     <- 'http://api.geonames.org/searchJSON?q='
  options      <- paste('&maxRows=',1,'&featureClass=P&style=FULL&fuzzy=',fuzzy,'&username=',api_key, sep="")
  options_retry <- paste('&maxRows=',1,'&featureClass=P&style=FULL&username=',api_key, sep="")
  query_string <- paste(city, state, country, sep=", ")
  # query_string <- paste(address1, address2, city, state, country, zip, sep=", ")
  
  url_string <- URLencode(paste0(base_url, query_string, options))
  
  if(debug) message(paste0('DEBUG: ',url_string, appendLF=T))
  
  # if(debug) message(paste0('DEBUG: ', 'geocode_gn(', query_string, ')'))
  # if(verbose) message(paste("Resolving: ", city.org, ", ", state.org, ", ", country.org, "... ", sep = ""), appendLF = F) 

  # query geocoder service, retry if necessary (default 3 times)
  for(i in 1:service_retries) 
  { 
    
    connect <- url(url_string)
    gc <- fromJSON(paste(readLines(connect,warn = FALSE), collapse = ""))
    close(connect)
    
    if(is.null(gc$totalResultsCount))
    {
      if(!is.null(gc$status$message) && !is.na(pmatch("the hourly limit", gc$status$message)))
      { 
        # "status":{"message":"the hourly limit of 2000 credits
        
        message(paste0("\nSERVICE LIMIT EXCEEDED, sleeping till ", Sys.time() + service_limit_sleep), appendLF=T)
        message(gc$status$message, appendLF=T)
        message(Sys.time(),appendLF=T)
        
        Sys.sleep(60*60+300) # 1 h 5 min default
      }  
      else
      {  
        message("\nSERVICE ERROR, retrying... ",appendLF=T)
        Sys.sleep(retry_delay) # 2 sec default
      }  
    }   
    else
    {
      # Success! carry on with the script
      break
    }  
  }
    
  if(!is.null(gc$totalResultsCount) && gc$totalResultsCount >= 1) 
  {  
    if(verbose) message("\nSUCCESS ",appendLF=F) 
  } 
  else # no results from geocoding service
  {
    # if(verbose) message(paste0(gc$status$message),appendLF=T)
  
    if(fuzzy != 1)
    {
        # retry without fuzzyness--sometimes improves the results
        message("Retrying without fuzzy search...", appendLF=T)
        url_string <- URLencode(paste0(base_url, query_string, options_retry))
        connect <- url(url_string)
        gc <- fromJSON(paste(readLines(connect,warn = FALSE), collapse = ""))
        close(connect)
        
        if(!is.null(gc$totalResultsCount) && gc$totalResultsCount >= 1) 
        {
          message("\nSUCCESS! ",appendLF=F) 
        }
        else
        {
          if(verbose) message("",appendLF=T)
          message(paste("NO RESULTS FOUND with or without fuzzy search", sep = ""))
          
          #return(data.frame(lon = NA, lat = NA))
          return(NA)  
        }  
    }    
    else 
    {
        if(verbose) message("",appendLF=T)
        message(paste("NO RESULTS FOUND", sep = ""))
    
        #return(data.frame(lon = NA, lat = NA))
        return(NA)    
    }
  } 

  
NULLtoNA <- function(x) 
{
    if (is.null(x)) 
      return(NA)
    x
}
  
gcdf <- with(gc$geonames[[1]], 
            {
             data.frame(	
                lon = as.numeric(NULLtoNA(lng)), 
                lat = as.numeric(NULLtoNA(lat)), 
                city = NULLtoNA(toponymName),
                state = NULLtoNA(adminName1),
                country = NULLtoNA(countryName),
                source_city = NULLtoNA(city.org),
                source_state = NULLtoNA(state.org),
                source_country = NULLtoNA(country.org),
                fclName = tolower(NULLtoNA(fclName)),
                fcodeName = tolower(NULLtoNA(fcodeName)), 
                population = NULLtoNA(population)
				      )                
            }
          )
  
  if(verbose) 
  { 
    if(toString(gcdf$city) != toString(city.org) | toString(gcdf$state) != toString(state.org) | toString(gcdf$country) != toString(country.org)) 
    {
      message(paste("--> ", gcdf$city,", ",gcdf$state,", ",gcdf$country, sep=""), appendLF=T) 
    } 
    else 
    {
      message("", appendLF=T)
    }    
  }  
  
  return(gcdf[, c("lon", "lat", "city", "state", "country", "source_city", "source_state", "source_country", "fclName", "fcodeName","population")])

}


