## R/GeoNames webservice interface

Geonames geocoding interface (alpha). Resolves addresses to lat and lon pairs using GeoNames webservice. Very early alpha code. Use at your own risk. Based on ggmap::geocode code by David Kahle.

  * Geonames API Terms of Service : http://www.geonames.org/about.html

  * Use of Geonames Geocoding requires free account: http://www.geonames.org/login


### Sample usage:

    if(geocode_refresh) #  || !ObjExists(loc)) 
    {       
       writeLines("Geocoding...")
       loc <- count(rs[ , c("city","state","country")]) # calculate frequency (number of respondents from a city)  

       geo.data <- geocoder(loc)
       geo <- geo.data$results   
       geo <- rename(geo, c("city"="city.resolved","state"="state.resolved","country"="country.resolved"))  
       geo <- rename(geo, c("source_city"="city","source_state"="state","source_country"="country"))

       loc <- join(loc, geo, match="first", by=c("city","state","country"))
       save(loc, geo, geo.data, file="geo_locations.RData")
     } else {
       writeLines("Skipping Geocoding, loading saved data...")
       load("geo_locations.RData")
     }
