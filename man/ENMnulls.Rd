% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/ENMnulls.R
\name{ENMnulls}
\alias{ENMnulls}
\title{Generate null ecological niche models (ENMs) and compare null with 
empirical performance metrics}
\usage{
ENMnulls(
  e,
  mod.settings,
  no.iter,
  eval.stats = c("auc.val", "auc.diff", "cbi.val", "or.mtp", "or.10p"),
  user.enm = NULL,
  user.eval = NULL,
  user.eval.type = NULL,
  userStats.signs = NULL,
  removeMxTemp = TRUE,
  parallel = FALSE,
  numCores = NULL,
  parallelType = "doSNOW",
  quiet = FALSE
)
}
\arguments{
\item{e}{ENMevaluation object}

\item{mod.settings}{named list: one set of model settings with which to 
build null ENMs.}

\item{no.iter}{numeric: number of null model iterations.}

\item{eval.stats}{character vector: the performance metrics that will be 
used to calculate null model statistics.}

\item{user.enm}{ENMdetails object: if implementing a user-specified model.}

\item{user.eval}{function: custom function for specifying performance metrics 
not included in \pkg{ENMeval}.
The function must first be defined and then input as the argument 
\code{user.eval}.}

\item{user.eval.type}{character: if implementing a user-specified model, 
specify here which evaluation type to use -- either "knonspatial", 
"kspatial", "testing", or "none".}

\item{userStats.signs}{named list: user-defined evaluation statistics
attributed with either 1 or -1 to designate whether the expected difference 
between empirical and null models is positive or negative; this is used to 
calculate the p-value of the z-score. For example, for AUC, the difference 
should be positive (the empirical model should have a higher score), whereas 
for omission rate it should be negative (the empirical model should have a 
lower score).}

\item{removeMxTemp}{boolean: if TRUE, delete all temporary data generated 
when using maxent.jar for modeling.}

\item{parallel}{boolean: if TRUE, use parallel processing.}

\item{numCores}{numeric: number of cores to use for parallel processing; 
if NULL, all available cores will be used.}

\item{parallelType}{character:: either "doParallel" or "doSNOW" 
(default: "doSNOW").}

\item{quiet}{boolean: if TRUE, silence all function messages 
(but not errors).}
}
\value{
An \code{ENMnull} object with slots containing evaluation summary 
statistics for the null models and their cross-validation results, as well 
as differences in results between the empirical and null models. 
This comparison table includes z-scores of these differences and their 
associated p-values (under a normal distribution). See ?ENMnull for more 
details.
}
\description{
\code{ENMnulls()} iteratively builds null ENMs for a single set 
of user-specified model settings based on an input ENMevaluation object, 
from which all other analysis settings are extracted. Summary statistics of 
the performance metrics for the null ENMs are taken (averages and standard 
deviations) and effect sizes and \emph{p}-values are calculated by comparing 
these summary statistics to the empirical values of the performance metrics 
(i.e., from the model built with the empirical data). See the references 
below for more details on this method.
}
\details{
This null ENM technique is based on the implementation in Bohl 
\emph{et al.} (2019), which follows the original methodology of Raes & ter 
Steege (2007) but makes an important modification: instead of evaluating 
each null model on random validation data, here we evaluate the null models 
on the same withheld validation data used to evaluate the empirical model. 
Bohl \emph{et al.} (2019) demonstrates this approach using a single defined 
withheld partition group, but Kass \emph{et al.} (2020) extended it to use 
spatial partitions by drawing null occurrences from the area of the predictor 
raster data defining each partition. Please see the vignette for a brief 
example.

This function avoids using raster data to speed up each iteration, and 
instead samples null occurrences from the partitioned background records. 
Thus, you should avoid running this when your background records are not well 
sampled across the study extent, as this limits the extent that null 
occurrences can be sampled from.
}
\examples{
\dontrun{
library(ENMeval)

# first, let's tune some models
occs <- read.csv(file.path(system.file(package="predicts"), 
"/ex/bradypus.csv"))[,2:3]
envs <- rast(list.files(path=paste(system.file(package="predicts"), 
                                   "/ex", sep=""), pattern="tif$", 
                                   full.names=TRUE))
bg <- as.data.frame(predicts::backgroundSample(envs, n = 10000))
names(bg) <- names(occs)

ps <- list(orientation = "lat_lat")

# as an example, let's use two user-specified evaluation metrics
conf.and.cons <- function(vars) {
  observations <- c(
    rep(x = 1, times = length(vars$occs.train.pred)),
    rep(x = 0, times = length(vars$bg.train.pred)),
    rep(x = 1, times = length(vars$occs.val.pred)),
    rep(x = 0, times = length(vars$bg.val.pred))
  )
  predictions <- c(vars$occs.train.pred, vars$bg.train.pred, 
  vars$occs.val.pred, vars$bg.val.pred)
  evaluation_mask <- c(
    rep(x = FALSE, times = length(vars$occs.train.pred) + 
    length(vars$bg.train.pred)),
    rep(x = TRUE, times = length(vars$occs.val.pred) + 
    length(vars$bg.val.pred))
  )
  measures <- confcons::measures(observations = observations, 
  predictions = predictions, 
  evaluation_mask = evaluation_mask, df = TRUE)
  measures.metrics <- measures[, c("CPP_eval", "DCPP")]
  colnames(measures.metrics) <- c("confidence", "consistency")
  return(measures.metrics)
}

e <- ENMevaluate(occs, envs, bg, 
                 tune.args = list(fc = c("L","LQ","LQH"), rm = 2:4), 
                 partitions = "block", partition.settings = ps, 
                 algorithm = "maxnet", categoricals = "biome",
                 user.eval  = conf.and.cons, parallel = TRUE)

d <- eval.results(e)

# here, we will choose an optimal model based on validation CBI, but you can
# choose yourself what evaluation statistics to use
opt <- d |> filter(cbi.val.avg == max(cbi.val.avg))

# now we can run our null models, and we can specify to include estimates for
# our user-specified variables too, but we need to make sure we note what 
# sign we expect these statistics to be 
# NOTE: you should use at least 100 iterations in practice -- this is just an
# example
nulls <- ENMnulls(e, 
                  mod.settings = list(fc = opt$fc, rm = opt$rm),
                  no.iter = 10, 
                  user.eval = conf.and.cons,
                  eval.stats = c("cbi.val", "confidence", "consistency"),
                  userStats.signs = c("confidence" = 1, "consistency" = 1))

# here are the results of all the null iterations
null.results(nulls)
# and here are the comparisons between the null and empirical values for
# the evaluation statistics, including the z-score and p-value
# for more details, see Bohl et al. 2019
null.emp.results(nulls)
}

}
\references{
Bohl, C. L., Kass, J. M., & Anderson, R. P. (2019). A new null model approach 
to quantify performance and significance for ecological niche models of 
species distributions. \emph{Journal of Biogeography}, \bold{46}: 1101-1111. 
\doi{10.1111/jbi.13573}

Kass, J. M., Anderson, R. P., Espinosa-Lucas, A., Juárez-Jaimes, V., 
Martínez-Salas, E., Botello, F.,  Tavera, G., Flores-Martínez, J. J., & 
Sánchez-Cordero, V. (2020). Biotic predictors with phenological information 
improve range estimates for migrating monarch butterflies in Mexico. 
\emph{Ecography}, \bold{43}: 341-352. \doi{10.1111/ecog.04886}

Raes, N., & ter Steege, H. (2007). A null-model for significance testing of 
presence-only species distribution models. \emph{Ecography}, \bold{30}: 
727-736. \doi{10.1111/j.2007.0906-7590.05041.x}
}
