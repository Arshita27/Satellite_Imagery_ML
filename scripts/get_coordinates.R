library(raster)

classificationfile <- raster("data/input/Nightlights/2013/F182013.v4c_web.stable_lights.avg_vis.tif")
xcoords <- xFromCol(classificationfile)
ycoords <- yFromRow(classificationfile)

values <- values(classificationfile)
NewRow <- rep(ycoords,each=NCOL(classificationfile))
NewCol <- rep(xcoords,NROW(classificationfile))

dNewCol <- round(NewCol,digits=8)
dNewRow <- round(NewRow,digits=8)
dvalues <- round(values,digits=0)

classframe <- data.frame(dNewCol,dNewRow,dvalues)

colnames(classframe) <- c("X","Y","Z")
write.table(classframe,file="data/intensity/Classification_XYZ.txt",sep=";",dec=".",row.names=F,col.names=T,quote=F)