library(tidyverse)
library(sf)
library(h3, lib.loc = "/home/amurra02/R/x86_64-pc-linux-gnu-library/4.4")
library(concaveman, lib.loc = "/home/amurra02/R/x86_64-pc-linux-gnu-library/4.4")
library(vroom)

print(paste0("Script Start @ ",round(Sys.time())))

# Get state fips from .sh script
st.fips <- Sys.getenv("VAR")
#st.fips <- "44"

fips.join <- vroom("/work/GRDVULN/sewershed/Data/fips_join.csv")%>%
  filter(state_code == st.fips)

# List probability files
prob.files <- data.frame(path = list.files("/work/GRDVULN/sewershed/Model/Apply_Boost/outputs/tables_clip", full.names = TRUE),
                         file = list.files("/work/GRDVULN/sewershed/Model/Apply_Boost/outputs/tables_clip", full.names = FALSE))%>%
  mutate(state = substr(file,18,19))%>%
  filter(state == st.fips)

# Drop Systems we have boundaries for
# Load hexagons for all systems not in training or testing
h3.swr <- vroom("/work/GRDVULN/sewershed/Data_Prep/Create_Validation/Data/ALL_sewersheds_h3.csv")%>%
  filter(substr(CWNS_ID,1,2)==st.fips)

print(paste0(length(unique(h3.swr$CWNS_ID))," previously delineated systems for state: ",st.fips))

# Load probability file
df.all <- vroom(prob.files$path, col_types = c("Near_CWNS"="c"))%>%
  mutate(UID = paste0(Near_CWNS,"-",h3_index))

# Filter out systems already assigned
df <- df.all%>%
  filter(!h3_index %in% h3.swr$H3_Index & !Near_CWNS %in% h3.swr$CWNS_ID)%>%
  select(UID,h3_index,Near_Rank,Near_CWNS,Prob_CRCT,Pop_2020,nBldgs,TOTAL_RES_POPULATION_2022,
         HU_90,HU_20,Pct_Sewer_90,E_Distance)

# data frame of population to add to ep.h3
sys.pop <- df%>%
  select(Near_CWNS,TOTAL_RES_POPULATION_2022)%>%
  drop_na(TOTAL_RES_POPULATION_2022)%>%
  distinct()

# Overwrite Hexagons with endpoints within them so that we force those hexagons to be assigned to the treatment plant within them.
ep.h3 <- vroom(paste0("/work/GRDVULN/sewershed/Data_Prep/01_Download_H3/outputs/STFP_",st.fips,".csv"),
               col_types = c("Near_CWNS"="c"))%>%
  filter(IS_EP == TRUE)%>%
  filter(!Near_CWNS %in% h3.swr$CWNS_ID & Near_CWNS %in% df$Near_CWNS)%>%
  mutate(Prob_CRCT = 1)%>%
  select(!IS_EP)%>%
  setNames(c("h3_index","E_Distance","Near_CWNS","Prob_CRCT"))%>%
  mutate(UID = paste0(Near_CWNS,"-",h3_index))%>%
  left_join(sys.pop, by = "Near_CWNS")

# Load systems to ignore
to.ignore <- read.csv("/work/GRDVULN/sewershed/Data_Prep/CWNS_to_Ignore/to_ignore.csv")

# df.ovr <- df%>%
#   filter(!h3_index %in% ep.h3$h3_index)%>%
#   filter(!Near_CWNS %in% to.ignore$CWNS_ID)%>%
#   bind_rows(ep.h3)%>%
#   mutate(Pop_2020 = replace_na(Pop_2020,0),
#          thresh = ifelse(TOTAL_RES_POPULATION_2022 <= 1000,0.77,
#                          ifelse(TOTAL_RES_POPULATION_2022 <= 5000, 0.62,
#                                 ifelse(TOTAL_RES_POPULATION_2022 <= 10000,0.42,
#                                        ifelse(TOTAL_RES_POPULATION_2022 <= 100000,0.15,0.01)))))

df.ovr <- df%>%
  filter(!h3_index %in% ep.h3$h3_index)%>%
  filter(!Near_CWNS %in% to.ignore$CWNS_ID)%>%
  bind_rows(ep.h3)%>%
  mutate(Pop_2020 = replace_na(Pop_2020,0),
         thresh = ifelse(TOTAL_RES_POPULATION_2022 <= 1000,0.7,
                         ifelse(TOTAL_RES_POPULATION_2022 <= 5000, 0.55,
                                ifelse(TOTAL_RES_POPULATION_2022 <= 10000,0.35,
                                       ifelse(TOTAL_RES_POPULATION_2022 <= 100000,0.08,0)))))

df.ovr$assigned <- FALSE
df.ovr$available <- TRUE


# Assign systems that were sewered in 1990
sewered <- vroom("/work/GRDVULN/sewershed/Model/Create_Boundaries/Sewered_1990.csv")%>%
  mutate(UID = paste0(Near_CWNS,"-",h3_index))

# Assign to data frame
#sewered.row.ids <- which(df.ovr$UID %in% sewered$UID)
#df.ovr$assigned[sewered.row.ids] <- TRUE

# sewered.h3.ids <- which(df.ovr$h3_index %in% sewered$h3_index)
# df.ovr$available[sewered.h3.ids] <- FALSE


# Create a target population for each system based on the total residential population - population of known sewered hexagons
# target.adjust <- df.ovr[sewered.row.ids,]%>%
#   group_by(Near_CWNS)%>%
#   summarise(Sewered_Pop = sum(Pop_2020, na.rm = TRUE))

# Order systems
systems <- df.ovr%>%
  select(Near_CWNS,TOTAL_RES_POPULATION_2022)%>%
  distinct()%>%
  arrange(TOTAL_RES_POPULATION_2022)%>%
  mutate(Target_Pop = TOTAL_RES_POPULATION_2022)%>%
  drop_na(TOTAL_RES_POPULATION_2022)

# TEMPORARY
#which(systems$Near_CWNS == "27001708001")

print(paste0("Assigning hexagons to ",nrow(systems)," systems @ ",round(Sys.time())))

sf_use_s2(FALSE)

no.candidates <- data.frame()
# Iterate through systems and assign

for(n in 1:nrow(systems)){
  # Set target population
  target.pop <- systems$Target_Pop[n]
  
  # Get the already sewered and assigned hexagons
  # sewered.system <- df.ovr%>%
  #   filter(Near_CWNS == systems$Near_CWNS[n] & UID %in% sewered$UID)
  
  # List candidate hexagons to add to CWNS ID
  candidates <- df.ovr%>%
    filter(Near_CWNS == systems$Near_CWNS[n] & available == TRUE & Prob_CRCT >= thresh)
  
  
  # If there are candidates, calculate the cumulative sum of population through descending probabilities
  if(nrow(candidates)>0){
    
    pop.sum <- candidates%>%
      arrange(desc(Prob_CRCT))%>%
      mutate(cumPop = cumsum(Pop_2020),
             dif = abs(cumPop - target.pop))
    
    # Determine row where population reaches target
    cutoff <- which(pop.sum$dif == min (pop.sum$dif))[1]
    if(nrow(candidates) > cutoff){cutoff <- cutoff+1}
    
    # Bind sewered hexagons with candidate hexagons
    cand.sel <- select(pop.sum[1:cutoff,],!c(cumPop,dif))
    
    #sewered.candidates <- rbind(sewered.system,cand.sel)
    
    # Create point layer for selected candidates & Sewered hexagons
    candidate.pts <- h3_to_geo_sf(cand.sel$h3_index)%>%
      st_transform(st_crs(5070))%>%
      left_join(cand.sel)
    
    # Create the boundary and check for spatial outliers
    shed.sf <- h3_to_geo_boundary_sf(cand.sel$h3_index)%>%
      summarise()%>%
      st_transform(st_crs(5070))
    
    # Explode multipolygon to multiple polygons
    explode <- shed.sf%>%
      st_cast("POLYGON")%>%
      st_make_valid()%>%
      mutate(area_km = as.numeric(st_area(.))/1000000)%>%
      arrange(desc(area_km))
    
    # For each polygon, determine Pct Area and distance from primary polygon
    if(nrow(explode)>1){
      
      # Calculate Percent area
      total.area <- sum(explode$area_km)
      
      explode$Pct_Area <- explode$area_km/total.area
      
      # Rank by Area
      explode.rank <- explode%>%
        arrange(desc(area_km))
      
      # Determine which secondary parts to keep using distance and area
      primary <- explode.rank[1,]
      
      secondary <- explode.rank[2:nrow(explode.rank),]
      secondary$distance <- as.numeric(st_distance(secondary,primary))/1000
      
      # Make decisions
      
      ## Logit Model
      secondary$TOTAL_RES_POPULATION_2022 <- systems$TOTAL_RES_POPULATION_2022[n]
      # secondary$Pred_Trim <- predict(logit.m, type = "response", newdata = secondary)
      # 
      # to.keep <- secondary%>%
      #   mutate(keep = ifelse(Pred_Trim >=1,TRUE,FALSE))%>%
      #   filter(keep == TRUE)
      
      # Logic
      to.keep <- secondary%>%
        mutate(keep = ifelse(Pct_Area < 0.05,FALSE,
                             ifelse(distance >= 5 & distance < 10 & Pct_Area < .1,FALSE,
                                    ifelse(distance >= 10 & Pct_Area < 0.3, FALSE,TRUE))))%>%
        filter(keep == TRUE)
      
      # If we're keeping parts, bind them back to the primary and summarise, then ID hexagons as final shed
      if(nrow(to.keep)>0){
        restitch <- bind_rows(primary,to.keep)%>%
          summarise()
        
        restitch.intrsct <- st_intersection(candidate.pts,restitch)
        
        final.shed <- restitch.intrsct%>%
          st_drop_geometry()%>%
          select(UID,h3_index,Near_CWNS,Prob_CRCT)
        
      } else({ # If we aren't keeping anything, identify hexagons in the primary polygon as the final selection
        final.shed <- st_intersection(candidate.pts,primary)%>%
          st_drop_geometry()%>%
          select(UID,h3_index,Near_CWNS,Prob_CRCT)
      })
      
      
    } else({ # If there are no disconnected polygons, identify the selected candidates and the sewered hexagons as the final selection.
      final.shed <- candidate.pts%>%
        st_drop_geometry()%>%
        select(UID,h3_index,Near_CWNS,Prob_CRCT)
    })
  } else({ # If no candidates were found, check for 1990 sewered hexagons, if there are none, then this CWNS has failed to be located.
    
    
    # if(nrow(sewered.system)>0){
    #   final.shed <- sewered.system%>%
    #     select(UID,h3_index,Near_CWNS,Prob_CRCT)
    # } else({
    newRow.noCands <- data.frame(CWNS_ID = systems$Near_CWNS[n],
                                 TOTAL_RES_POPULATION_2022 = systems$TOTAL_RES_POPULATION_2022[n],
                                 No_Candidates = TRUE)
    no.candidates <- rbind(no.candidates, newRow.noCands)
  })
  
  # Mark the selected hexagons as assigned and unavailable
  
  # Assign hexagons to system
  hex.assign <- which(df.ovr$UID %in% final.shed$UID)
  df.ovr$assigned[hex.assign] <- TRUE
  
  # Mark hexagons as unavailable
  hex.remove <- which(df.ovr$h3_index %in% final.shed$h3_index)
  df.ovr$available[hex.remove] <- FALSE
  
  
  if(n %% 20 == 0){
    print(paste0(round(100*(n/nrow(systems)),1),"% Complete @ ", round(Sys.time())))
  }
  
}


print(paste0("Failed to find boundaries for ",nrow(no.candidates)," Systems"))

write.csv(no.candidates,paste0("/work/GRDVULN/sewershed/Model/Create_Boundaries/outputs/Max_Prob/Fail/FP_",st.fips,".csv"))


print(paste0("Saving outputs @ ",round(Sys.time())))

# Create data frame of boundary statistics and join them to the convex hull geometries
stats <- df.ovr%>%
  filter(assigned == TRUE)

# Save hexagon stats
vroom_write(stats,paste0("/work/GRDVULN/sewershed/Model/Create_Boundaries/outputs/Max_Prob/text/Selections_",st.fips,".csv"),delim = ",", append = FALSE)

swr.stats <- stats%>%
  group_by(Near_CWNS)%>%
  summarise(TOTAL_RES_POPULATION_2022 = TOTAL_RES_POPULATION_2022[1],
            Pop_2020 = round(sum(Pop_2020,na.rm = TRUE)),
            Min_Prob = min(Prob_CRCT, na.rm = TRUE),
            Mean_Prob = mean(Prob_CRCT, na.rm = TRUE),
            Buildings = sum(nBldgs, na.rm = TRUE))


boundaries.out <- h3_to_geo_boundary_sf(stats$h3_index)%>%
  left_join(stats, by = "h3_index")%>%
  group_by(Near_CWNS)%>%
  summarise()%>%
  left_join(swr.stats, by = "Near_CWNS")%>%
  select(Near_CWNS,TOTAL_RES_POPULATION_2022,
         Pop_2020,Min_Prob,Mean_Prob,Buildings)


# Save boundaries
st_write(boundaries.out,paste0("/work/GRDVULN/sewershed/Model/Create_Boundaries/outputs/Max_Prob/Boundaries/FP_",st.fips,".gpkg"), layer = "sewersheds",
         append = FALSE)

print(paste0("Script Complete @ ",round(Sys.time())))
