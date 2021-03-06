library(shiny)
library(googlesheets4)
gs4_deauth()

library(dplyr)
library(googleway)
library(leaflet)
library(stringr)

source('secret.R')
set_key(key = gmap_key)

df <- df_gsheet %>%
  mutate(search_string = paste(name, city, country))

# get google map info

# create a dataframe that has all the place details, to cbind to the original df
place_details <- matrix(ncol=8,nrow=0)
colnames(place_details) <- c('google_name','id', 'address','lat','lng','open_now','rating','num_ratings') 

for (place in df$search_string) {
  r_api <- google_places(search_string = place)$results 
  
  if (length(r_api) == 0) {
    # if api results are empty, append a blank row
    place_details = rbind(place_details, NA)
  } else {
    # if api results aren't empty, take the first result and the relevant columns
    
    r_api <- r_api %>% slice(1)
    row_details <- cbind(r_api$name, r_api$id, 
                         r_api$formatted_address, r_api$geometry$location$lat, r_api$geometry$location$lng,
                         r_api$opening_hours$open_now, r_api$rating, r_api$user_ratings_total)
    
    place_details = rbind(place_details, row_details)
  }
  
}

df <- cbind(df, place_details)

df$lat = as.numeric(df$lat)
df$lng = as.numeric(df$lng)


#get unique categories
group_type <- df$type %>% str_split("; ") %>% unlist() %>%unique()

marker_pal <- colorFactor("RdYlBu", domain =group_type)

icon.fa <- makeAwesomeIcon(icon = 'circle', markerColor = "blue", library='fa', iconColor = '#ffffff')

# create the popup content
df <- df %>%
  mutate(popup = paste0("<b>", name, "</b><br/><b>Type:</b> ", type, "<br/>",
                        as.character(rating), " ✩, ", as.character(num_ratings), " reviews"))

m <- leaflet() %>%
  addProviderTiles(providers$CartoDB.Positron)

# add layers for each type
for (t in group_type) {
  m <- m %>%
    addAwesomeMarkers(data = df %>% filter(grepl(t, type)), ~lng, ~lat, icon = icon.fa, 
                      label = ~name, popup = ~popup, group = t)
}

# add layer controls
m <- m %>%
  addLayersControl(overlayGroups = group_type,
                   options = layersControlOptions(collapsed = FALSE))





# Define server logic
shinyServer(function(input, output) {
  output$map <- renderLeaflet({
    m
  }) 
  
})
