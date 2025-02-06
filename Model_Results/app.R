#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    https://shiny.posit.co/
#

library(tidymodels)
library(shiny)
library(bslib)
library(dplyr)
library(stringr)
library(vroom)
library(plotly)
library(sf)
library(leaflet)
library(crosstalk)
library(tidycensus)


# Load spatial data
#train.sf <- st_read("Model_Results/Predicted.gpkg", layer = "training")
train.sf <- st_read("Predicted.gpkg", layer = "training")%>%
  mutate(fColor = ifelse(Sewered == TRUE,"#42a1f5","#d47435"))
#predicted.sf <- st_read("Model_Results/Predicted.gpkg", layer = "predicted")
predicted.sf <- st_read("Predicted.gpkg", layer = "predicted")

# Load sewersheds

# Get list of states and counties for selection
st.cnty <- tidycensus::fips_codes%>%
  mutate(ST_Cnty = paste0(state_code,county_code))%>%
  select(ST_Cnty,state_name,county)%>%
  filter(ST_Cnty %in% predicted.sf$ST_CNTY)

#perf <- vroom("Model_Results/Models_1_500.csv")%>%
perf <- vroom("Models_1_500.csv")%>%
  mutate(label = paste0("<b>Model: </b>", Model,"<br>",
                        "<b>Accuracy: </b>", round(Accuracy,4),"<br>",
                        "<b>Sensitivity: </b>", round(Sensitivity,4),"<br>",
                        "<b>Specificity: </b>", round(Specificity,4),"<br>",
                        "<b>Trees: </b>", Trees,"<br>",
                        "<b>mTry: </b>", mTry,"<br>",
                        "<b>Variables: </b><br>", str_replace_all(vars,pattern = "-","<br>")
  ))

var.list <- unique(unlist(str_split(perf$vars, pattern = "-")))

#impr <- vroom("Model_Results/Model_Importance_1_500.csv")
impr <- vroom("Model_Importance_1_500.csv")

perf.vars <- colnames(perf)[c(2:5,7:10)]

# Define UI for application that draws a histogram
ui <- page_navbar(title = "Sewershed Model Results",
                  nav_panel("Review Parameters",
                            layout_columns(
                              card(
                                h3("Model Variables"),
                                selectInput(
                                  "xvar",
                                  "X Variable",
                                  perf.vars,
                                  selected = "nVars"
                                ),
                                selectInput(
                                  "yvar",
                                  "Y Variable",
                                  perf.vars,
                                  selected = "Trees"
                                ),
                                selectInput(
                                  "colvar",
                                  "Color Variable",
                                  perf.vars,
                                  selected = "Accuracy"
                                ),
                                h3("Predictor Control"),
                                checkboxGroupInput(
                                  "check",
                                  "Show Models With: ",
                                  var.list,
                                  selected = var.list
                                ),
                                textOutput('temp')
                              ),
                              card(
                                card_header("Scatter Plot"),
                                plotlyOutput("scatter")
                              ),
                              card(
                                card_header("Importance"),
                                plotlyOutput("imprtPlot")
                              ),
                              col_widths = c(2,5,5))
                  ),
                  nav_panel(title = "Map Best Models",
                            layout_columns(
                              card(selectInput("state","Choose State",
                                               choices = st.cnty$state_name,
                                               selected = "Maryland"),
                                   selectInput("county","Choose County",
                                               choices = st.cnty$county)),
                              card(selectInput("model","Choose Model to Inspect",
                                               choices = colnames(predicted.sf)[4:13])),
                              card(sliderInput("cutoff","Select Cutoff for Classification",
                                               0,1,0.5,0.01),
                                   actionButton("select","Apply Changes")),
                              col_widths = c(4,4,4)),
                            leafletOutput("map")
                  )
)

# Define server logic
server <- function(input, output, session) {
  
  # Reactive value for checkboxes
  check.box <- reactive(input$check)
  
  # Create the scatter plot
  scatter.sub <- reactive({
    if(length(check.box() > 0)){
      scatter.sel <- perf[,c(input$xvar,input$yvar,input$colvar,"vars","label")]
      
      scatter.sel <- scatter.sel%>%
        setNames(c("x","y","col","vars","label"))%>%
        filter(grepl(paste0(check.box(), collapse = "|"),vars))
    }
    
    if(is.null(check.box())){
      scatter.sel <- perf[,c(input$xvar,input$yvar,input$colvar,"vars","label")]
      
      scatter.sel <- scatter.sel%>%
        setNames(c("x","y","col","vars","label"))
    }
    
    return(scatter.sel)
  })
  
  output$scatter <- renderPlotly({
    plot_ly(scatter.sub())%>%
      add_markers(x = ~x, y = ~y, color = ~col, text = ~label, hoverinfo = 'text', size = 5)%>%
      layout(xaxis = list(title = input$xvar),
             yaxis = list(title = input$yvar), legend = list(title=list(text=input$colvar)))
  })
  
  
  # Importance Plot
  imprt.sub <- reactive(impr%>%
                          filter(Variable %in% input$check))
  
  output$imprtPlot <- renderPlotly({
    plot_ly(imprt.sub())%>%
      add_boxplot(x = ~Importance, y = ~Variable)
  })
  
  
  # Create shared data frame for model review and mapping
  
  # Reactive counties for selection
  counties <- reactive({
    cnty.sub <- st.cnty%>%
      filter(state_name == input$state)
    
    return(cnty.sub$county)
  })
  
  shiny::observe({
    updateSelectInput(session, "county",
                      choices = counties()
    )})
  
  

  
  
  observeEvent(input$select,{
    
    cnty.h3 <- st.cnty%>%
      filter(state_name == input$state & county == input$county)
    
    # Subset model predictions
    pred.sub <- predicted.sf%>%
      filter(ST_CNTY %in% cnty.h3$ST_Cnty)%>%
      select(h3_index,Sewered_TRUTH,which(colnames(.)==input$model))%>%
      setNames(c("h3_index","Sewered_Truth","Probability","geom"))%>%
      mutate(Class = ifelse(Probability > input$cutoff,TRUE,FALSE),
             pColor = ifelse(Probability < (input$cutoff/2),"#a6611a",
                             ifelse(Probability< (input$cutoff - 0.1),"#dfc27d",
                                    ifelse(Probability < (input$cutoff + 0.1),"#f5f5f5",
                                           ifelse(Probability < (input$cutoff*2),"#80cdc1",
                                                  ifelse(Probability < 1.1,"#018571","#919191"))))))
    
    # Create color palette for predictions
    # pal <- colorNumeric(
    #   palette = "PiYG",
    #   domain = c(0,))
    
    # Subset training data
    train.sub <- train.sf%>%
      filter(ST_CNTY %in% cnty.h3$ST_Cnty)
    
    output$map <- renderLeaflet({
      leaflet(pred.sub)%>%
        addTiles()%>%
        addPolygons(data = train.sub, fillColor = ~fColor, weight = 1, color = "grey20", fillOpacity = 0.7)%>%
        addPolygons(fillColor = ~pColor, weight = 1, color = "grey20", fillOpacity = 0.7,
                    popup = ~Probability)
    })
  })
  
}

# Run the application 
shinyApp(ui = ui, server = server)
