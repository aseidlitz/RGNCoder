## R/GeoNames webservice interface

Geonames geocoding interface (alpha). Resolves addresses to lat and lon pairs using GeoNames webservice. Very early alpha code, use at your own risk. Based on ggmap::geocode code by David Kahle.

I tried several geocoding services supported in R, but none of them were suitable either due to the restrictive terms of use (Google) or the accuracy (CloudMade). Google, for example, states: "The Geocoding API may only be used in conjunction with a Google map; geocoding results without displaying them on a map is prohibited"  https://developers.google.com/maps/documentation/geocoding/. 

Since I needed to geocode locations for different purposes I tried a few services and settled on [GeoNames](http://www.geonames.org). It imposes some limits on the numbers of queries per hour and per day, but the accuracy is better than on CloudMade (at least in my testing of rural Canadian addresses). CloudMade looks very promising and inexpensive, but the resolution quality needs to improve. They also provide awesome map tiles. This script could be easily repurposed to work with CloudMade geocoder API as well. 

If you using a free GeoNames account, the script will respect usage limits, and continue processing when service will become available. 

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
