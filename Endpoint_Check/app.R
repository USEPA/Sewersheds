#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#

library(shiny)
library(leaflet)
library(leafem)
library(vroom)
library(dplyr)
library(ggplot2)
library(tidyr)
library(here)
library(gt)
library(pins)
library(rsconnect)
library(bslib)
library(leafpm)
library(shinyalert)
library(sf)

# Testing
# PIN URL: https://rstudio-connect.dmap-stage.aws.epa.gov/content/0b59a94d-2b56-47af-97d4-19488dc09e11/
# API Key: us1c5geWMiDftE0if2CatDVAdDoV6fSN

#setwd(here::here("Endpoint_Check"))
# connect to the Posit Connect pin board
my_board <- pins::board_connect(auth = "manual", server = "https://rstudio-connect.dmap-stage.aws.epa.gov",
                                key = "us1c5geWMiDftE0if2CatDVAdDoV6fSN")
# my_board <- pins::board_connect(auth = "rsconnect", server = "rstudio-connect.dmap-stage.aws.epa.gov",
#                                 account = "Andrew")

# Load decisions made already
made <- pin_read(my_board, name = "Andrew/ep_decisions")

# Load facility info
# info.df <- vroom("data/FACILITY_TYPES.txt", col_types = c("CWNS_ID"="c"))%>%
#   mutate(UID = paste0(CWNS_ID,"-",FACILITY_ID))%>%
#   select(UID,STATE_CODE,FACILITY_TYPE,CHANGE_TYPE)

info.all <- vroom("data/ep_all_info.csv", col_types = c("CWNS_ID"="c"))%>%
  select(!c(X,Y))

# Load endpoint locations
endpoints <- vroom("data/ep_s.csv", col_types = c("CWNS_ID"="c"))%>%
  mutate(UID = paste0(CWNS_ID,"-",FACILITY_ID))%>%
  left_join(info.all)
# ep <- vroom("data/ep_s.csv", col_types = c("CWNS_ID"="c"))%>%
#   filter(!CWNS_ID %in% made$CWNS_ID)%>%
#   mutate(UID = paste0(CWNS_ID,"-",FACILITY_ID))%>%
#   left_join(info.all)%>%
#   select(STATE_NAME,CWNS_ID,FACILITY_ID,FACILITY_NAME,TOTAL_RES_POPULATION_2022,X,Y,STATE_CODE,facilities,changes)%>%
#   distinct()

states <- sort(unique(endpoints$STATE_NAME))

# Create random sequence of rows
#set.seed(123)
# order <- sample(nrow(ep),nrow(ep), replace = FALSE)
# ep <- ep[order,]

# Set n = 1

n <- 1

# Define UI for application that draws a histogram
ui <- page_navbar(
  title = "End Point Reviewer",
  nav_panel(title = "Check End Points",
            page_fillable(
              layout_columns(
                card(
                  h2(textOutput("name")),
                  leafletOutput("map"),
                  gt_output("facilityInfo")),
                card(
                  selectizeInput("state","Choose a State", choices = states, selected = states),
                  h3("Does this location reflect a possible end point?"),
                  radioButtons(
                    "decision",
                    label = "Choice",
                    choices = c("Yes","No","Unsure"),
                    selected = "Unsure",
                    inline = FALSE,
                    width = NULL,
                    choiceNames = NULL,
                    choiceValues = NULL),
                  textInput("reviewer", "Reviewer Name", value = ""),
                  actionButton("nextMap", "Submit & Next Facility"),
                  br(),
                  h4("Instructions"),
                  actionButton("help", "How to Move a Point")),
                card(
                  h3("Results"),
                  h2(textOutput("count")),
                  plotOutput("pie")),
                col_widths = c(6, 3, 3)))),
  nav_panel(title = "Review Decisions",
            page_fillable(
              layout_columns(
                card(
                  h3("Filters"),
                  checkboxGroupInput("resultFilt",
                                     label = "Show Decisions",
                                     choices = c("Yes","No","Unsure"),
                                     selected = c("Yes","No","Unsure")),
                  br(),
                  h3("Download"),
                  downloadButton('Ddownload',"Download Decisions"),
                  downloadButton('Cdownload',"Download Point Changes")
                  ),
                card(
                  leafletOutput("reviewMap")),
                col_widths = c(2,10)
                )
            ))
)
  
# Define server logic required to draw a histogram
server <- function(input, output) {

  
  # Filter ep if state selection is used
  ep <- reactive({
    endpoints%>%
      filter(!CWNS_ID %in% made$CWNS_ID)%>%
      filter(STATE_NAME %in% input$state)%>%
      select(STATE_NAME,CWNS_ID,FACILITY_ID,FACILITY_NAME,TOTAL_RES_POPULATION_2022,X,Y,STATE_CODE,facilities,changes)%>%
      distinct()%>%
      mutate(order = sample(seq(1,nrow(.)),nrow(.), replace = FALSE))%>%
      arrange(order)
  }) 
  
  # Help Window
  observeEvent(input$help, {
    # Show a modal when the button is pressed
    shinyalert("Move an End Point", tags$video(src = "Move_Location.mp4",
                                               type = "video/mp4",
                                               autoplay = FALSE,
                                               controls = TRUE,
                                               width="600"),
               type = "info", html = TRUE, size = 'l')
  })
  
  # Load existing decisions
  #df <- pin_read(my_board, name = "Andrew/ep_decisions")
  
  ep.idx <- reactiveVal()
  ep.idx(1)
  
  
  # Facility Name (Initial)
  output$name <- renderText(ep()$FACILITY_NAME[ep.idx()])
  output$count <- renderText(paste0("Endpoints Reviewed: ",nrow(made)))
  
  # Initial Map
  output$map <- renderLeaflet({
    leaflet()%>%
      addProviderTiles("Esri.WorldImagery")%>%
      addCircleMarkers(lat = ep()$Y[ep.idx()], lng = ep()$X[ep.idx()],
                       weight = 3, color = "#54c3e8", opacity = 1, fillOpacity = 0, radius = 20, group = "editable")%>%
      setView(lat = ep()$Y[ep.idx()], lng = ep()$X[ep.idx()], zoom = 15)%>%
      addPmToolbar(targetGroup = "editable",
                   toolbarOptions = pmToolbarOptions(drawMarker=T,
                                                     drawPolygon = F,
                                                     drawCircle = F,
                                                     drawPolyline = F,
                                                     drawRectangle = F,
                                                     editMode = T,
                                                     cutPolygon = F,
                                                     removalMode = T,
                                                     position="topleft"))%>%
      addMouseCoordinates()
  })
  
  # Initial Facility Table
  output$facilityInfo <- render_gt({
    
    col.select <- ep()[ep.idx(),]%>%
      mutate(TOTAL_RES_POPULATION_2022 = format(TOTAL_RES_POPULATION_2022,big.mark = ","))%>%
      select(CWNS_ID,FACILITY_ID,STATE_CODE,TOTAL_RES_POPULATION_2022,facilities,changes)
    long <- data.frame(name = c("CWNS ID","Facility ID","State","Population","Facility Types","Changes"),
                       value = as.character(col.select[1,]))
    
    gt(long)%>%
      tab_options(column_labels.hidden = TRUE)%>%
      tab_style(
        style = list(
          cell_text(weight = "bold")
        ),
        locations = cells_body(
          columns = name
        )
      )
  })
  
  # Initial Pie Chart
  # Create Pie Chart of Decisions
  df.pie <- reactive({
    made%>%
    group_by(Good_Loc)%>%
    summarise(count = n())%>%
    mutate(prop = count/sum(count))
  })
  
  output$pie <- renderPlot({
    ggplot(df.pie(), aes(x = "", y = prop, fill = Good_Loc))+
      geom_bar(stat = "identity", width = 1, color = "white")+
      coord_polar("y", start = 0)+
      theme_void()+
      scale_fill_manual(values = c("Yes"="#32a852","No"="#a6261f","Unsure" = "grey30"))+
      labs(fill = "Good Location?")
  })
  
  # When submit is clicked, save selection then update map to next end point
  observeEvent(input$nextMap,{
    
    # Get decision
    newRow <- data.frame(CWNS_ID = as.character(ep()$CWNS_ID[ep.idx()]),
                         Good_Loc = input$decision,
                         Reviewer = input$reviewer,
                         TimeStamp = Sys.time(),
                         X = ep()$X[ep.idx()],
                         Y = ep()$Y[ep.idx()])
    
    # Load decisions from pin
    df.decisions <- pin_read(my_board, name = "Andrew/ep_decisions")%>%
      mutate(CWNS_ID = as.character(CWNS_ID))
    
    # Update decisions
    df.decisions <- rbind(df.decisions,newRow)
    
    # Update number of decisions made
    output$count <- renderText(paste0("Endpoints Reviewed: ",nrow(df.decisions)))
    
    # Save new decision
    pin_write(my_board, df.decisions, "Andrew/ep_decisions")
    
    # Check to see if a new location has been proposed
    # Get the polygon that has been drawn
    # coords<-data.frame(do.call(rbind, do.call(cbind,input$map_draw_new_feature$geometry$coordinates)))
    if(exists("input$map_draw_new_feature$geometry$coordinates")){
      coords<-data.frame(input$map_draw_new_feature$geometry$coordinates)
      colnames(coords)<-c("long", "lat")
      
      sf <- coords %>%
        st_as_sf(coords = c("long", "lat"), crs = 4326) %>%
        summarise(geometry = st_combine(geometry)) %>%
        st_cast("POINT")
      
      if (!is.null(sf)) {
        sf.out <- sf%>%
          mutate(CWNS_ID = ep()$CWNS_ID[ep.idx()],
                 Edited = input$reviewer,
                 TimeStamp = Sys.time())
        
        # Load dataset
        moved.exist <- pin_read(my_board, name = "Andrew/ep_moved")
        # Combine new data
        moved.new <- rbind(moved.exist,sf.out)
        # Save new data
        pin_write(my_board,moved.new, name = "Andrew/ep_moved")
      }
    }
    
    # Increase index by 1
    ep.idx(ep.idx()+1)
    
    # Update map title
    output$name <- renderText(ep()$FACILITY_NAME[ep.idx()])
    
    # Update Map
    leafletProxy("map")%>%
      clearMarkers()%>%
      addCircleMarkers(lat = ep()$Y[ep.idx()], lng = ep()$X[ep.idx()],
                       weight = 3, color = "#54c3e8", opacity = 1, fillOpacity = 0, radius = 20, group = "editable")%>%
      setView(lat = ep()$Y[ep.idx()], lng = ep()$X[ep.idx()], zoom = 14)
    
    # Update facility info table
    output$facilityInfo <- render_gt({
      
      col.select <- ep()[ep.idx(),]%>%
        mutate(TOTAL_RES_POPULATION_2022 = format(TOTAL_RES_POPULATION_2022,big.mark = ","))%>%
        select(CWNS_ID,FACILITY_ID,STATE_CODE,TOTAL_RES_POPULATION_2022,facilities,changes)
      long <- data.frame(name = c("CWNS ID","Facility ID","State","Population","Facility Types","Changes"),
                         value = as.character(col.select[1,]))
      
      gt(long)%>%
        tab_options(column_labels.hidden = TRUE)%>%
        tab_style(
          style = list(
            cell_text(weight = "bold")
          ),
          locations = cells_body(
            columns = name
          )
        )
    })
    
    
    # Create Pie Chart of Decisions
    df.pie <- df.decisions%>%
      group_by(Good_Loc)%>%
      summarise(count = n())%>%
      mutate(prop = count/sum(count))
    
    output$pie <- renderPlot({
      ggplot(df.pie, aes(x = "", y = prop, fill = Good_Loc))+
        geom_bar(stat = "identity", width = 1, color = "white")+
        coord_polar("y", start = 0)+
        theme_void()+
        scale_fill_manual(values = c("Yes"="#32a852","No"="#a6261f","Unsure" = "grey30"))+
        labs(fill = "Good Location?")
    })
  })
  
  # Generate Review Map
  ## Initial map
  output$reviewMap <- renderLeaflet({
    
    made.info <- pin_read(my_board, name = "Andrew/ep_decisions")%>%
      filter(Good_Loc %in% input$resultFilt)%>%
      left_join(info.all)
    
    leaflet(made.info)%>%
      addProviderTiles("Esri.WorldImagery")%>%
      addCircleMarkers(lat = ~Y, lng = ~X,
                       color = ~ ifelse(Good_Loc == "Yes","#32a852",
                                        ifelse(Good_Loc == "No",
                                               "#a6261f","grey30")),
                       weight = 3, opacity = 1,fillOpacity = 0.7, radius = 10,
                       popup = ~paste("<b>",FACILITY_NAME,"</b><br>",
                                      "<b>CWNS ID:</b> ",CWNS_ID,"<br>",
                                      "<b>Facility ID:</b> ",FACILITY_ID,"<br>",
                                      "<b>Reviewed By:</b> ", Reviewer,"<br>",
                                      "<b>Reviewed On:</b> ", as.Date(TimeStamp),"<br>",
                                      "<b>Location Okay?</b> ",Good_Loc,"<br>",
                                      "<b>Facility Types:</b> ",facilities,"<br>",
                                      "<b>Change Types:</b> ", changes
                       ))%>%
      setView(lat = 38.60, lng = -97.29, zoom = 4)
  })
  
  ## Update Map
  observe({
    df.filt <- pin_read(my_board, name = "Andrew/ep_decisions")%>%
      filter(Good_Loc %in% input$resultFilt)%>%
      left_join(info.all)
      
      leafletProxy("reviewMap")%>%
        clearMarkers()%>%
        addCircleMarkers(data = df.filt, lat = ~Y, lng = ~X,
                         color = ~ ifelse(Good_Loc == "Yes","#32a852",
                                          ifelse(Good_Loc == "No",
                                                 "#a6261f","grey30")),
                         weight = 3, opacity = 1,fillOpacity = 0.7, radius = 10,
                         popup = ~paste("<b>",FACILITY_NAME,"</b><br>",
                                        "<b>CWNS ID:</b> ",CWNS_ID,"<br>",
                                        "<b>Facility ID:</b> ",FACILITY_ID,"<br>",
                                        "<b>Reviewed By:</b> ", Reviewer,"<br>",
                                        "<b>Reviewed On:</b> ", as.Date(TimeStamp),"<br>",
                                        "<b>Location Okay?</b> ",Good_Loc,"<br>",
                                        "<b>Facility Types:</b> ",facilities,"<br>",
                                        "<b>Change Types:</b> ", changes
                                        ))
  })
  
  # Data Downloads
  
  ## Decisions
  df.decisions <- reactive(
    pin_read(my_board, name = "Andrew/ep_decisions")%>%
      mutate(CWNS_ID = as.character(CWNS_ID)))
    
    output$Ddownload <- downloadHandler(
      filename = function(){"EP_Decisions.csv"}, 
      content = function(fname){
        write.csv(df.decisions(), fname)
      })

  ## Suggested Changes
  df.changes <- reactive(
    pin_read(my_board, name = "Andrew/ep_moved")%>%
      mutate(CWNS_ID = as.character(CWNS_ID))%>%
      cbind(as.data.frame(st_coordinates(.)))%>%
      st_drop_geometry()
  )
  
  output$Cdownload <- downloadHandler(
    filename = function(){"EP_Changes.csv"}, 
    content = function(fname){
      write.csv(df.changes(), fname, row.names = FALSE)
    })

    
    
  
  
    
    
    
    
}

# Run the application 
shinyApp(ui = ui, server = server)
