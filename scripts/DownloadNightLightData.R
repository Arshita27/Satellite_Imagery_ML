## DownloadNightLightData.R 
# R code to download data from https://ngdc.noaa.gov 
# to be used as input in subsequent model training

# setwd('csc591-predicting-poverty')
rm(list=ls())
require(R.utils)

# function to check if a directory is already present, and 
# create a new directory else replace the existing one.
check_and_createDir <- function(dir_name){
    dir_status <- dir.exists(dir_name)
    if(dir_status == FALSE){
        dir.create(dir_name)
        dir_status <- TRUE
    }else{
        unlink(dir_name,recursive = TRUE)
        dir.create(dir_name)
    }
}

parent_dir <- 'data/input/Nightlights'
dir.create(parent_dir)
loc <- 'https://ngdc.noaa.gov/eog/data/web_data/v4composites/F18'
extn <- '.v4.tar'
prefix <- '/F18'
search_file <- 'stable_lights.avg_vis.tif.gz'
data_range <- c(2010,2011,2012,2013)
for (i in data_range){
    folder <- paste0(parent_dir,'/')
    new_dir <- paste0(folder, i)
    x <- dir.create(new_dir)
    ifelse(x,print("Directory creation successful."),print("Directory not found."))
    download_to <- paste0(new_dir,prefix,i,extn)
    addr <- paste0(loc,i,extn)
    download.file(addr,download_to,quiet = FALSE,mode = "w",cacheOK = TRUE)
    print(paste0("Data for year ",i," downloaded"))
    print(paste0("Extracting files..."))
    untar(download_to, exdir = new_dir,verbose = FALSE)
    file <- list.files(new_dir)
    file <- file[substr(file, nchar(file)-27, nchar(file))==search_file]
    tif <- paste0(new_dir, '/', file)
    file <- substr(file, 1, nchar(file)-3)
    gunzip(tif, paste0(new_dir, '/', file),FUN = gzfile,overwrite = FALSE, remove = TRUE)
    unlink(paste0(new_dir, '/', list.files(new_dir)[list.files(new_dir)!=file]), recursive = T)
    print(paste0("Operations for year ",i," completed."))
}
unload(R.utils)
