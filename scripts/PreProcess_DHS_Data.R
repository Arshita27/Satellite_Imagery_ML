## PreProcess_DHS_Data.R
# Script to perform pre-processing operations on the downloaded DHS data
# and store it in files in /output/ folder
# The file and directory structure is kept the same as mentioned by author of paper(Neal Jean et. all.)

rm(list=ls())
required_packages <- c('rgdal','magrittr','foreign','readstata13','plyr','dplyr','raster')
lapply(required_packages,require,character.only = TRUE)
src <- 'data/input/Nightlights/'
delta <- 0.5

# Finding the value to be assigned for each 10 sq.km patch and 
# subsequently roll-up the data to clusters
assign_meanVal <- function(data_val, year,avail_data){
    file_log <- list.files(paste0(src, year))
    night_data <- raster(paste0(src, year, '/', file_log))
    # filtering NA and 0 valued records
    filter_data <- data_val %>%
        filter(!is.na(lat) & lat!=0 & !is.na(lon) & lon!=0)
    # removing duplicates
    filter_data <- unique(filter_data[,c('lat', 'lon')])
    # Creating spatial object from the matrix
    mat_a <- range(c(filter_data$lon-delta, filter_data$lon+delta))
    mat_b <- range(c(filter_data$lat-delta, filter_data$lat+delta))
    obj <- extent(c(mat_a,mat_b))
    night_data <- crop(night_data,obj)
    radius <- 6378137
    theta <- 5000/radius
    x <- (360/(2*pi))
    range <- 1:nrow(filter_data)
    for (i in range){
        dev_lat <- x*theta
        x_lat <- filter_data$lat[i] - dev_lat
        y_lat <- filter_data$lat[i] + dev_lat
        lat <- sort(c(x_lat, y_lat))
        dev_lon <- x*theta/cos(filter_data$lat[i])
        x_lon <- filter_data$lon[i] - dev_lon
        y_lon <- filter_data$lon[i] + dev_lon
        lon <- sort(c(x_lon, y_lon))
        ext <- extent(lon, lat)
        extr <- extract(night_data, ext)
        dat_extr <- unlist(extr)
        dat_extr[dat_extr==255] <- NULL
        filter_data$night_data[i] <- mean(dat_extr, na.rm = T, trim = 0)
        filter_data$sample[i] <- ifelse(round(filter_data$lat[i], 6) %in% avail_data,0,1)
        
    }
    merged_data <- table_join(filter_data, data_val)
    return(merged_data)
}

#Merge two data frames and remove NAs from them
table_join <- function(df1,df2){
    df_new <- na.omit(df1)
    df2_new <- merge(df_new,df2,by = c('lat','lon'))
    return (df2_new)
}

# Aggregate household-level data to cluster level
rollup_data <- function(data_val){
    # computing aggregate values and performing roll-up
    new_data <- na.omit(data_val)
    tot_val <- nrow(data_val)
    range <- 1:tot_val
    for (i in range){
        sub <- subset(data_val, lat == data_val$lat[i] & lon == data_val$lon[i])
        data_val$n[i] <- nrow(sub)
    }
    new_data <- table_join(new_data,data_val)
    new_data <- new_data %>%
        filter(!is.na(new_data[,1])) %>%
        mutate(new_lat = lat*0.95, new_lon = lon*0.95)
    # splitting the data frame, performing aggreagtion and 
    # returning the results into a dataframe
    data_val <- ddply(data_val, .(lat, lon), summarise, wealthscore = mean(wealthscore),
                      night_data = mean(night_data), n = mean(n), sample = min(sample))
    return(data_val)
}

# Preprocessing the DHS survey data
extract <- raster::extract
avail_data <- c(0.112190, -1.542321, -1.629748, -1.741995, -1.846039, -1.896059, -2.371342, -2.385341, -2.446988)

dhs <- 'data/output/DHS'
dir.create(dhs, showWarnings = FALSE, recursive = FALSE)

get_dta <- function(file_loc,cols){
    df <- read.dta(file_loc,convert.factors = NA)
    df <- df %>%
        subset(select = cols)
    return (df)
}

ug_src <- 'data/input/DHS/UG_2011_DHS_04022018_1051_118965/ughr60dt/UGHR60FL.DTA'
ug_latlon <- 'data/input/DHS/UG_2011_DHS_04022018_1051_118965/ugge61fl/UGGE61FL.dbf'
tz_src <- 'data/input/DHS/TZ_2010_DHS_04022018_1051_118965/tzhr63dt/TZHR63FL.DTA'
tz_latlon <- 'data/input/DHS/TZ_2010_DHS_04022018_1051_118965/tzge61fl/TZGE61FL.dbf'
ng_src <- 'data/input/DHS/NG_2013_DHS_04022018_1053_118965/nghr6adt/NGHR6AFL.DTA'
ng_latlon <- 'data/input/DHS/NG_2013_DHS_04022018_1053_118965/ngge6afl/NGGE6AFL.dbf'
mw_src <- 'data/input/DHS/MW_2010_DHS_04022018_1053_118965/mwhr61dt/MWHR61FL.DTA'
mw_latlon <- 'data/input/DHS/MW_2010_DHS_04022018_1053_118965/mwge62fl/MWGE62FL.dbf'
rw_src <- 'data/input/DHS/RW_2010_DHS_04022018_1053_118965/rwhr61dt/RWHR61FL.DTA'
rw_latlon <- 'data/input/DHS/RW_2010_DHS_04022018_1053_118965/rwge61fl/RWGE61FL.dbf'
select_cols <- c('DHSCLUST', 'LATNUM', 'LONGNUM')
new_name <- c('cluster', 'lat', 'lon')
filter_cols <- c('hhid','hv001','hv005','hv271')
sel_cols <- c('hhid', 'cluster', 'weight', 'wealthscore')

# Country   : Malawi
# Year      : 2010
process_DHS_data_mw <- function(){
    data_year <- 2010
    mw_data <- read.dta(mw_src,convert.factors = FALSE)
    mw_data <- mw_data[,filter_cols]
    names(mw_data) <- sel_cols
    # merge the two dataframes into the first one to perform join operation on 'cluster' col
    mw_loc <- read.dbf(mw_latlon)
    mw_loc <- mw_loc[,select_cols]
    names(mw_loc) <- new_name
    
    mw_data <- merge(mw_data, mw_loc, by = 'cluster', all = FALSE, sort = TRUE) %>%
        assign_meanVal(data_year,avail_data)
    
    household_info <- 'data/output/DHS/Malawi 2010 DHS (Household).txt'
    agg_file <- 'data/output/DHS/Malawi 2010 DHS (Cluster).txt'
    agg_data <- rollup_data(mw_data)
    write.table(mw_data, household_info, row.names = FALSE, col.names = TRUE)
    write.table(agg_data, agg_file, row.names = FALSE, col.names = TRUE)
}
process_DHS_data_mw()

# Country   : Nigeria
# Year      : 2013
process_DHS_data_ng <- function(){
    data_year <- 2013
    ng_data <- read.dta(ng_src, convert.factors = NA)
    ng_data <- ng_data[,filter_cols]
    names(ng_data) <- sel_cols
    # merge the two dataframes into the first one to perform join operation on 'cluster' col
    ng_loc <- read.dbf(ng_latlon)
    ng_loc <- ng_loc[,select_cols]
    names(ng_loc) <- new_name
    
    ng_data <- merge(ng_data, ng_loc, by = 'cluster', all = FALSE, sort = TRUE) %>%
        assign_meanVal(data_year,avail_data)
    
    household_info <- 'data/output/DHS/Nigeria 2013 DHS (Household).txt'
    agg_file <- 'data/output/DHS/Nigeria 2013 DHS (Cluster).txt'
    agg_data <- rollup_data(ng_data)
    write.table(ng_data, household_info, row.names = FALSE, col.names = TRUE)
    write.table(agg_data, agg_file, row.names = FALSE, col.names = TRUE)
}
process_DHS_data_ng()

# Country   : Rwanda
# Year      : 2010
process_DHS_data_rw <- function(){
    rw_data <- read.dta(rw_src,convert.factors = FALSE)
    rw_data <- rw_data[,filter_cols]
    names(rw_data) <- sel_cols
    
    rw_latlon <- read.dbf(rw_latlon)
    rw_latlon <- rw_latlon[,select_cols]
    
    names(rw_latlon) <- new_name
    
    rw_data <- merge(rw_data, rw_latlon, by = 'cluster', all = FALSE, sort = TRUE) %>%
        assign_meanVal(2010,avail_data)
    household_info <- 'data/output/DHS/Rwanda 2010 DHS (Household).txt'
    agg_file <- 'data/output/DHS/Rwanda 2010 DHS (Cluster).txt'
    agg_data <- rollup_data(rw_data)
    write.table(rw_data, household_info, row.names = FALSE, col.names = TRUE)
    write.table(agg_data, agg_file, row.names = FALSE, col.names = TRUE)
}
process_DHS_data_rw()

# Country   : Tanzania
# Year      : 2010
process_DHS_data_tz <- function(){
    data_year <- 2010
    tz_data <- read.dta(tz_src,convert.factors = NA)
    tz_data <- tz_data[,filter_cols]
    names(tz_data) <- sel_cols
    
    tz_loc <- read.dbf(tz_latlon)
    tz_loc <- tz_loc[,select_cols]
    names(tz_loc) <- new_name
    # merge the two dataframes into the first one to perform join operation on 'cluster' col
    tz_data <- merge(tz_data, tz_loc, by = 'cluster', all = FALSE, sort = TRUE) %>%
        assign_meanVal(data_year,avail_data)
    household_info <- 'data/output/DHS/Tanzania 2010 DHS (Household).txt'
    agg_file <- 'data/output/DHS/Tanzania 2010 DHS (Cluster).txt'
    agg_data <- rollup_data(tz_data)
    write.table(tz_data, household_info, row.names = FALSE, col.names = TRUE)
    write.table(agg_data, agg_file, row.names = FALSE, col.names = TRUE)
}
process_DHS_data_tz()

# Country   : Uganda
# Year      : 2011
process_DHS_data_ug <- function(){    
    data_year <- 2011
    ug_data <- read.dta(ug_src,convert.factors=NA)
    ug_data <- ug_data[,filter_cols]
    # ug_data <- get_dta(src,filter_cols)
    names(ug_data) <- sel_cols
    ug_loc <- read.dbf(ug_latlon)
    ug_loc <- ug_loc[,select_cols]
    names(ug_loc) <- new_name
    # merge the two dataframes into the first one to perform join operation on 'cluster' col
    ug_data <- merge(ug_data, ug_loc, by = 'cluster', all = FALSE, sort = TRUE) %>% 
        assign_meanVal(data_year,avail_data)
    
    household_info <- 'data/output/DHS/Uganda 2011 DHS (Household).txt'
    agg_file <- 'data/output/DHS/Uganda 2011 DHS (Cluster).txt'
    agg_data <- rollup_data(ug_data)
    write.table(ug_data, household_info, row.names = FALSE, col.names = TRUE)
    write.table(agg_data, agg_file, row.names = FALSE, col.names = TRUE)
}
process_DHS_data_ug()

