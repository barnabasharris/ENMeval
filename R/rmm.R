#' @title Build metadata object from ENMeval results

#' @description Builds a \code{rangeModelMetadata} object from the output of \code{ENMevaluate}.
#' See Merow \emph{et al.} (2019) for more details on the nature of the metadata and the \code{rangeModelMetadata} package.
#' To improve reproducibility of the study, this metadata object can be used as supplemental information for a manuscript, shared with collaborators, etc.
#' @param e ENMevaluation object
#' @param envs SpatRaster: environmental predictor variables used in analysis; needed to pull information on the predictor variables
#' not included in the ENMevaluation object
#' @param rmm rangeModelMetadata object: if included, fields are appended to this RMM object as opposed to returning a new RMM object
#' @references Merow, C., Maitner, B. S., Owens, H. L., Kass, J. M., Enquist, B. J., Jetz, W., & Guralnick, R. (2019). Species' range model metadata standards: RMMS. \emph{Global Ecology and Biogeography}, \bold{28}: 1912-1924. \doi{10.1111/geb.12993}
#' @export

buildRMM <- function(e, envs, rmm = NULL) {
  if(is.null(rmm)) {
    rmm <- rangeModelMetadata::rmmTemplate()  
  }
  
  rmm$code$software$packages <- paste("ENMeval", packageVersion("ENMeval"))
  
  # occurrence/background metadata ####
  rmm$data$occurrence$taxon <- e@taxon.name
  rmm$data$occurrence$dataType <- "presence only"
  rmm$data$occurrence$presenceSampleSize <- nrow(e@occs)
  rmm$data$occurrence$backgroundSampleSize <- nrow(e@bg)
  
  # predictor variable metadata ####
  if(!is.null(envs)) {
    rmm$data$environment$variableNames <- names(envs)
    rmm$data$environment$resolution <- terra::res(envs)[1]
    rmm$data$environment$extent <- as.character(terra::ext(envs))
    rmm$data$environment$projection <- as.character(terra::crs(envs)) 
  }
  
  # settings for tuning
  rmm$model$tuneSettings <- e@tune.settings
  
  # partition metadata ####
  rmm$model$partition$numberFolds <- length(unique(e@occs.grp))

  if(e@partition.method == "randomkfold") {
    rmm$model$partition$partitionSet <- "random k-fold"
    rmm$model$partition$partitionRule <- "random partition assignment with user-specified number of partitions"
    rmm$model$partition$occurrenceSubsampling <- "k-fold cross validation"
  }
  if(e@partition.method == "jackknife") {
    rmm$model$partition$partitionSet <- "jackknife (leave-one-out)"
    rmm$model$partition$partitionRule <- "leave-one-out partitions (each occurrence locality receives its own partition)"
    rmm$model$partition$occurrenceSubsampling <- "k-fold cross validation"
  }
  if(e@partition.method == "block") {
    rmm$model$partition$partitionSet <- "spatial block"
    rmm$model$partition$partitionRule <- "four spatial partitions defined by latitude/longitude lines that ensure a balanced number of occurrence localities across partitions"
    rmm$model$partition$notes <- "background points also partitioned"
    rmm$model$partition$occurrenceSubsampling <- "k-fold cross validation"
  }
  if(e@partition.method == "checkerboard" & length(e@partition.settings$aggregation.factor) == 1) {
    rmm$model$partition$partitionSet <- "binary checkerboard"
    rmm$model$partition$partitionRule <- "two spatial partitions in a checkerboard formation that subdivide geographic space equally but do not ensure a balanced number of occurrence localities across partitions"
    rmm$model$partition$notes <- "background points also partitioned"
    rmm$model$partition$occurrenceSubsampling <- "k-fold cross validation"
  }
  if(e@partition.method == "checkerboard" & length(e@partition.settings$aggregation.factor) == 2) {
    rmm$model$partition$partitionSet <- "hierarchical checkerboard"
    rmm$model$partition$partitionRule <- "four spatial partitions with two levels of spatial aggregation in a checkerboard formation that subdivide geographic space equally but do not ensure a balanced number of occurrence localities across partitions"
    rmm$model$partition$notes <- "background points also partitioned"
    rmm$model$partition$occurrenceSubsampling <- "k-fold cross validation"
  }
  if(e@partition.method == "checkerboard") {
    rmm$model$partition$notes <- paste('aggregation factor =', e@partition.settings$aggregation.factor)
  }
  if(e@partition.method == "testing") {
    rmm$model$partition$partitionSet <- "testing"
    rmm$model$partition$partitionRule <- "evaluation on a testing dataset"
    rmm$model$partition$occurrenceSubsampling <- "none"
  }
  if(e@partition.method == "user") {
    rmm$model$partition$partitionSet <- "user-specified"
    rmm$model$partition$occurrenceSubsampling <- "k-fold cross validation"
  }
  if(e@partition.method == "none") {
    rmm$model$partition$partitionSet <- "none"
    rmm$model$partition$occurrenceSubsampling <- "none"
  }
  
  # model metadata ####
  if(e@algorithm == "maxent.jar") {
    rmm$model$algorithms <- paste(e@algorithm, maxentJARversion())
    rmm$model$algorithmCitation <- "Phillips, S. J., Anderson, R. P., Dud\u161k, M., Schapire, R. E., & Blair, M. E. (2017). Opening the black box: An open-source release of Maxent. Ecography, 40(7), 887-893."
  }
  if(e@algorithm == "maxnet") {
    rmm$model$algorithms <- paste(e@algorithm, packageVersion("maxnet"))
    rmm$model$algorithmCitation <- citation("maxnet")
  }
  if(e@algorithm == "boostedRegressionTrees") {
    rmm$model$algorithms <- paste(e@algorithm, "using gbm", packageVersion('gbm'))
    rmm$model$algorithmCitation <- c(citation("gbm"))
    rmm$model$algorithm$brt$interactionDepth <- unique(e@tune.settings$tree.complexity)
    rmm$model$algorithm$brt$bagFraction <- unique(e@tune.settings$bag.fraction)
    rmm$model$algorithm$brt$learningRate <- unique(e@tune.settings$learning.rate)
    rmm$model$algorithm$brt$distribution <- "binomial"
    rmm$model$algorithm$brt$nTrees <- sapply(e@models, function(x) x$n.trees)
    rmm$model$algorithm$brt$shrinkage <- sapply(e@models, function(x) x$shrinkage)
  }
  if(e@algorithm == "randomForest") {
    rmm$model$algorithms <- paste(e@algorithm, "using randomForest", packageVersion('randomForest'))
    rmm$model$algorithmCitation <- citation("randomForest")
    rmm$model$algorithm$randomForest$ntree <- unique(e@tune.settings$ntree)
    rmm$model$algorithm$randomForest$mtry <- unique(e@tune.settings$mtry)
    rmm$model$algorithm$randomForest$maxnodes <- "default: maximum possible"
  }
  if(e@algorithm == "bioclim") {
    rmm$model$algorithms <- paste(e@algorithm, "using envelope() function in predicts", packageVersion("predicts"))
    rmm$model$algorithmCitation <- "Booth, T. H., Nix, H. A., Busby, J. R., & Hutchinson, M. F. (2014). BIOCLIM: the first species distribution modelling package, its early applications and relevance to most current MAXENT studies. Diversity and Distributions, 20(1), 1-9."
  }
  if(e@algorithm == "maxnet" | e@algorithm == "maxent.jar") {
    rmm$model$algorithm$maxent$featureSet <- unique(e@tune.settings$fc)
    rmm$model$algorithm$maxent$regularizationMultiplierSet <- unique(e@tune.settings$rm)
    rmm$model$algorithm$maxent$clamping <- e@other.settings$clamp
    rmm$model$algorithm$maxent$samplingBiasRule <- 'ignored'
    rmm$model$algorithm$maxent$notes <- "cloglog transformation used for model predictions"
  }
  
  
  # evaluation metadata ####
  if(e@partition.method == "testing") {
    rmm$assessment$testingDataStats$AUC <- paste(e@tune.settings$tune.args, e@results$auc.val.avg, sep = ": ")
    rmm$assessment$testingDataStats$AUCDiff <- paste(e@tune.settings$tune.args, e@results$auc.diff.avg, sep = ": ")
    rmm$assessment$testingDataStats$boyce <- ifelse(!is.null(e@results$cbi.val.avg), paste(e@tune.settings$tune.args, e@results$cbi.val.avg, sep = ": "), "none")
    rmm$assessment$testingDataStats$omissionRate <- list(or.mtp = paste(e@tune.settings$tune.args, round(e@results[grepl("or.mtp",names(e@results))], 3), sep = ": "),
                                                            or.10p = paste(e@tune.settings$tune.args, round(e@results[grepl("or.10p",names(e@results))], 3), sep = ": "))
  }else{
    rmm$assessment$trainingDataStats$AUC <- paste(e@tune.settings$tune.args, round(e@results$auc.train, 3), sep = ": ")
    rmm$assessment$trainingDataStats$boyce <- paste(e@tune.settings$tune.args, round(e@results$cbi.train, 3), sep = ": ")
    rmm$assessment$validationDataStats$AUC <- paste(e@tune.settings$tune.args, e@results$auc.val.avg, sep = ": ")
    rmm$assessment$validationDataStats$AUCDiff <- paste(e@tune.settings$tune.args, e@results$auc.diff.avg, sep = ": ")
    rmm$assessment$validationDataStats$boyce <- ifelse(!is.null(e@results$cbi.val.avg), paste(e@tune.settings$tune.args, e@results$cbi.val.avg, sep = ": "), "none")
    rmm$assessment$validationDataStats$omissionRate <- list(or.mtp = paste(e@tune.settings$tune.args, round(e@results[grepl("or.mtp",names(e@results))], 3), sep = ": "),
                                                            or.10p = paste(e@tune.settings$tune.args, round(e@results[grepl("or.10p",names(e@results))], 3), sep = ": "))
  }
  
  return(rmm)
}
