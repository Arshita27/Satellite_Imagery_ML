## PreProcess_LSMS_Data.R
# R Script to perform pre-processing operations on the downloaded LSMS data
# and store it in files in /output/ folder

#setwd('predicting-poverty')
rm(list=ls())
required_packages <- c('rgdal','magrittr','foreign','readstata13','plyr','dplyr','raster')
lapply(required_packages,require,character.only = TRUE)
src <- 'data/input/Nightlights/'
delta <- 0.5

#Merge two data frames and remove NAs from them
table_join <- function(df1,df2){
    df_new <- na.omit(df1)
    df2_new <- merge(df_new,df2,by = c('lat','lon'))
    return (df2_new)
}

# Finding the value to be assigned for each 10 sq.km patch and 
# subsequently roll-up the data to clusters
assign_meanVal <- function(df, year,avail_data){
    file_log <- list.files(paste0(src, year))
    night_data <- raster(paste0(src, year, '/', file_log))
    # filtering NA and 0 valued records
    filter_data <- df %>%
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
    merged_data <- table_join(filter_data, df)
    return(merged_data)
}

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
    data_val <- ddply(data_val, .(lat, lon), summarise, cons = mean(cons),
              night_data = mean(night_data),n = mean(n),sample = min(sample))
    
    return(data_val)
}

# Overriding the extract method
extract <- raster::extract
lsms <- 'data/output/LSMS'
dir.create(lsms, showWarnings = FALSE, recursive = FALSE)
# the values were taken manually from the downloaded data
avail_data <- c(0.112190, -1.542321, -1.629748, -1.741995, -1.846039, -1.896059, -2.371342, -2.385341, -2.446988)

# Processing data for Malawi
process_data_Malawi <- function(){
    loc <- 'data/input/LSMS/MWI_2013_IHPS_v01_M_STATA/'
    p <- 116.28
    q <- 166.12
    d <- 365
    scale_fact <- 107.62
    init_year <- 2013
    house_file <- 'HouseholdGeovariables_IHPS_13.dta'
    hh_file <- 'HH_MOD_A_FILT_13.dta'
    hh_file2 <- 'HH_MOD_F_13.dta'
    
    malawi_consumption <- read.dta(paste0(loc,'Round 2 (2013) Consumption Aggregate.dta')) %$%
        data.frame(hhid = y2_hhid, cons = rexpagg/(d*adulteq), weight = hhweight)
    malawi_consumption$cons <- malawi_consumption$cons*scale_fact/(p*q)
    malawi_pos <- read.dta(paste0(loc,house_file), convert.factors = FALSE)
    hhid_geo_data <- malawi_pos$y2_hhid
    geo_lat_data <- malawi_pos$LAT_DD_MOD
    geo_lon_data <- malawi_pos$LON_DD_MOD
    malawi_latlon <- data.frame(hhid = hhid_geo_data, lat = geo_lat_data, lon = geo_lon_data)
    malawi_hha <- read.dta(paste0(loc,hh_file))
    hhid_data <- malawi_hha$y2_hhid
    rural_data <- malawi_hha$baseline_rural
    malawi_type <- data.frame(hhid = hhid_data, rururb = rural_data, stringsAsFactors = F)
    malawi_hhf <- read.dta(paste0(loc,hh_file2))
    hhid_f_data <- malawi_hhf$y2_hhid
    room_data <- malawi_hhf$hh_f10
    iron_data <- malawi_hhf$hh_f10=='IRON SHEETS'
    malawi_room <- data.frame(hhid = hhid_f_data, room = room_data)
    malawi_metal <- data.frame(hhid = hhid_f_data, metal = iron_data)
    
    malawi_final <- list(malawi_consumption, malawi_latlon, malawi_type, malawi_room, malawi_metal) %>%
        Reduce(function(x, y) merge(x, y, by = 'hhid'), .) %>%
        assign_meanVal(init_year,avail_data)
    
    household_info <- 'data/output/LSMS/Malawi 2013 LSMS (Household).txt'
    agg_file <- 'data/output/LSMS/Malawi 2013 LSMS (Cluster).txt'
    agg_data <- rollup_data(malawi_final)
    write.table(malawi_final, household_info, row.names = FALSE, col.names = TRUE)
    write.table(agg_data, agg_file, row.names = FALSE, col.names = TRUE)
}
process_data_Malawi()

# Processing data for Nigeria
process_data_Nigeria <- function(){
    loc_consumption <- 'data/input/LSMS/DATA/cons_agg_w2.dta'
    loc_pos <- 'data/input/LSMS/DATA/Geodata Wave 2/NGA_HouseholdGeovars_Y2.dta'
    loc_weight <- 'data/input/LSMS/DATA/HHTrack.dta'
    loc_harvest <- 'data/input/LSMS/DATA/Post Harvest Wave 2/Household/sect8_harvestw2.dta'
    p <- 7953
    q <- 110.84
    d <- 365
    init_year <- 2013
    niger_consumption <- read.dta(loc_consumption) %$%
        data.frame(hhid = hhid, cons = pcexp_dr_w2/d)
    niger_consumption$cons <- niger_consumption$cons*q/p
    niger_pos <- read.dta(loc_pos, convert.factors = FALSE)
    hhid_data <- niger_pos$hhid
    lat_data <- niger_pos$LAT_DD_MOD
    lon_data <- niger_pos$LON_DD_MOD
    niger_latlon <- data.frame(hhid = hhid_data, lat = lat_data, lon = lon_data)
    niger_type <- data.frame(hhid = niger_pos$hhid, rururb = niger_pos$sector, stringsAsFactors = FALSE)
    niger_weight <- read.dta(loc_weight, convert.factors = FALSE)[,c('hhid', 'wt_wave2')]
    names(niger_weight)[2] <- 'weight'
    niger_postHarvest <- read.dta(loc_harvest, convert.factors = FALSE)
    hhid_harvest_data <- niger_postHarvest$hhid
    room_data <- niger_postHarvest$s8q9
    iron_data <- niger_postHarvest$s8q7=='IRON SHEETS'
    niger_room <- data.frame(hhid = hhid_harvest_data, room = room_data)
    niger_metal <- data.frame(hhid = hhid_harvest_data, metal = iron_data)
    
    niger_final <- list(niger_consumption, niger_latlon, niger_type, niger_weight, niger_room, niger_metal) %>%
        Reduce(function(x, y) merge(x, y, by = 'hhid'), .) %>%
        assign_meanVal(init_year,avail_data)
    household_info <- 'data/output/LSMS/Nigeria 2013 LSMS (Household).txt'
    agg_file <- 'data/output/LSMS/Nigeria 2013 LSMS (Cluster).txt'
    agg_data <- rollup_data(niger_final)
    write.table(niger_final, household_info, row.names = FALSE, col.names = TRUE)
    write.table(agg_data, agg_file, row.names = FALSE, col.names = TRUE)
}
process_data_Nigeria()

# Processing data for Tanzania
process_data_Tanzania <- function(){
    loc <- 'data/input/LSMS/TZA_2012_LSMS_v01_M_STATA_English_labels/'
    p <- 130.72
    q <- 141.01
    vals <- c(p,q)
    mean_val <- mean(vals)
    scaled_nr <- 112.69
    scaled_val <- 585.52*mean_val
    tot_d <- 365
    init_year <- 2013
    house_file <- 'HouseholdGeovars_Y3.dta'
    consump_file <- 'ConsumptionNPS3.dta'
    sector_file <- 'HH_SEC_A.dta'
    sector_file2 <- 'HH_SEC_I.dta'
    
    tanz_consumption <- read.dta(paste0(loc,consump_file)) %$%
        data.frame(hhid = y3_hhid, cons = expmR/(tot_d*adulteq))
    tanz_consumption$cons <- tanz_consumption$cons*scaled_nr/scaled_val
    tanz_pos <- read.dta13(paste0(loc,house_file))
    lat_data <- tanz_pos$lat_dd_mod
    lon_data <- tanz_pos$lon_dd_mod
    tanz_latlon <- data.frame(hhid = tanz_pos$y3_hhid, lat = lat_data, lon = lon_data)
    tanz_house <- read.dta(paste0(loc,sector_file))
    hhid_data <- tanz_house$y3_hhid
    rural_data <- tanz_house$y3_rural
    tanz_type <- data.frame(hhid = hhid_data, rururb = rural_data, stringsAsFactors = F)
    tanz_weight <- read.dta(paste0(loc,sector_file))[,c('y3_hhid', 'y3_weight')]
    names(tanz_weight) <- c('hhid', 'weight')
    tanz_hhi <- read.dta(paste0(loc,sector_file2))
    hhid_data <- tanz_hhi$y3_hhid
    room_info <- tanz_hhi$hh_i07_1
    metal_info <- tanz_hhi$hh_i09=='METAL SHEETS (GCI)'
    tanz_room <- na.omit(data.frame(hhid = hhid_data, room = room_info))
    tanz_metal <- data.frame(hhid = hhid_data, metal = metal_info)
    
    tanz_final <- list(tanz_consumption, tanz_latlon, tanz_type, tanz_weight, tanz_room, tanz_metal) %>%
        Reduce(function(x, y) merge(x, y, by = 'hhid'), .) %>%
        assign_meanVal(init_year,avail_data)
    
    household_info <- 'data/output/LSMS/Tanzania 2013 LSMS (Household).txt'
    agg_file <- 'data/output/LSMS/Tanzania 2013 LSMS (Cluster).txt'
    agg_data <- rollup_data(tanz_final)
    write.table(tanz_final, household_info, row.names = FALSE, col.names = TRUE)
    write.table(agg_data, agg_file, row.names = FALSE, col.names = TRUE)
}
process_data_Tanzania()

# Processing data for Uganda
process_data_Uganda <- function(){
    loc <- 'data/input/LSMS/UGA_2011_UNPS_v01_M_STATA/'
    p <- 66.68
    q <- 71.55
    vals <- c(p,q)
    mean_val <- mean(vals)
    scale_fact <- 118.69
    res_amt <- 30*946.89
    init_year <- 2012
    agg_file <- 'UNPS 2011-12 Consumption Aggregate.dta'
    geo_file <- 'UNPS_Geovars_1112.dta'
    weight_file <- 'GSEC1.dta'
    hh_file <- 'GSEC9A.dta'
    uganda_consumption <- read.dta(paste0(loc,agg_file)) %$% data.frame(hhid = HHID, cons = welfare*scale_fact/(res_amt*mean_val))
    uganda_pos <- read.dta(paste0(loc,geo_file))
    hhid_data <- uganda_pos$HHID
    lat_data <- uganda_pos$lat_mod
    lon_data <- uganda_pos$lon_mod
    urb_data <- uganda_pos$urban
    uganda_latlon <- data.frame(hhid = hhid_data, lat = lat_data, lon = lon_data,
                                check.rows = FALSE,check.names = TRUE)
    uganda_type <- data.frame(hhid = hhid_data, rururb = urb_data,
                              stringsAsFactors = FALSE,check.rows = FALSE,check.names = TRUE)
    uganda_weight <- read.dta(paste0(loc,weight_file))[,c('HHID', 'mult')]
    names(uganda_weight) <- c('hhid', 'weight')
    uganda_housing <- read.dta(paste0(loc,hh_file))
    hhid_data <- uganda_housing$HHID
    room_data <- uganda_housing$h9q3
    ironRoof_data <- uganda_housing$h9q4=='Iron sheets'
    uganda_r <- data.frame(hhid = hhid_data, room = room_data)
    uganda_roof <- data.frame(hhid = hhid_data, roof = ironRoof_data)
    uganda_final <- list(uganda_consumption, uganda_type, uganda_latlon, uganda_weight, uganda_r, uganda_roof) %>%
        Reduce(function(x,y) merge(x, y, by = 'hhid'), .) %>%
        assign_meanVal(init_year,avail_data)
    
    household_info <- 'data/output/LSMS/Uganda 2012 LSMS (Household).txt'
    agg_file <- 'data/output/LSMS/Uganda 2012 LSMS (Cluster).txt'
    agg_data <- rollup_data(uganda_final)
    write.table(uganda_final, household_info, row.names = FALSE)
    write.table(agg_data, agg_file, row.names = FALSE)
}
process_data_Uganda()
