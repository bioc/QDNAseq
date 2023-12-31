setGeneric("applyFilters", function(object, residual=TRUE, blacklist=TRUE,
    mappability=NA, bases=NA, chromosomes=c("X", "Y"),
    verbose=getOption("QDNAseq::verbose", TRUE))
    standardGeneric("applyFilters"))
setGeneric("callBins", function(object, organism=c("human", "other"),
    method=c("CGHcall", "cutoff"),
    cutoffs=log2(c(deletion=0.5, loss=1.5, gain=2.5, amplification=10) / 2),
    ...)
    standardGeneric("callBins"))
setGeneric("compareToReference", function(object, references, force=FALSE)
    standardGeneric("compareToReference"))
setGeneric("correctBins", function(object, fit=NULL,
    method="ratio", adjustIncompletes=TRUE, ...)
    standardGeneric("correctBins"))
setGeneric("estimateCorrection", function(object, span=0.65, family="symmetric",
    adjustIncompletes=TRUE, maxIter=1, cutoff=4.0,
    variables=c("gc", "mappability"), ...)
    standardGeneric("estimateCorrection"))
setGeneric("highlightFilters", function(object, col="red", residual=NA,
    blacklist=NA, mappability=NA, bases=NA, type="union", ...)
    standardGeneric("highlightFilters"))
setGeneric("isobarPlot", function(x, y, ...)
    standardGeneric("isobarPlot"))
setGeneric("makeCgh", function(object, filter=TRUE,
    chromosomeReplacements=c(X=23, Y=24, MT=25), ...)
    standardGeneric("makeCgh"))
setGeneric("noisePlot", function(x, y, ...)
    standardGeneric("noisePlot"))
setGeneric("normalizeBins", function(object, method="median", force=FALSE,
    verbose=getOption("QDNAseq::verbose", TRUE))
    standardGeneric("normalizeBins"))
setGeneric("normalizeSegmentedBins", function(object, inter=c(-0.1, 0.1),
    force=FALSE) standardGeneric("normalizeSegmentedBins"))
setGeneric("poolRuns", function(object, samples, force=FALSE)
    standardGeneric("poolRuns"))
setGeneric("segmentBins", function(object, smoothBy=FALSE,
    alpha=1e-10, undo.splits="sdundo", undo.SD=1.0,
    force=FALSE, transformFun="log2", ...)
    standardGeneric("segmentBins"))
setGeneric("smoothOutlierBins", function(object,
    logTransform=TRUE, force=FALSE, ...)
    standardGeneric("smoothOutlierBins"))


setGeneric("binsToUse", function(object) standardGeneric("binsToUse"))

setGeneric("chromosomes", function(object) standardGeneric("chromosomes"))
setGeneric("bpstart", function(object) standardGeneric("bpstart"))
setGeneric("bpend", function(object) standardGeneric("bpend"))

setGeneric("counts", function(object) standardGeneric("counts"))
setGeneric("fit", function(object) standardGeneric("fit"))
setGeneric("copynumber", function(object) standardGeneric("copynumber"))
setGeneric("segmented", function(object) standardGeneric("segmented"))
setGeneric("calls", function(object) standardGeneric("calls"))
setGeneric("probdloss", function(object) standardGeneric("probdloss"))
setGeneric("probloss", function(object) standardGeneric("probloss"))
setGeneric("probnorm", function(object) standardGeneric("probnorm"))
setGeneric("probgain", function(object) standardGeneric("probgain"))
setGeneric("probamp", function(object) standardGeneric("probamp"))

setGeneric("binsToUse<-", function(object, value)
    standardGeneric("binsToUse<-"))

setGeneric("counts<-", function(object, value)
    standardGeneric("counts<-"))
setGeneric("fit<-", function(object, value)
    standardGeneric("fit<-"))
setGeneric("copynumber<-", function(object, value)
    standardGeneric("copynumber<-"))
setGeneric("segmented<-", function(object, value)
    standardGeneric("segmented<-"))
setGeneric("calls<-", function(object, value)
    standardGeneric("calls<-"))
setGeneric("probdloss<-", function(object, value)
    standardGeneric("probdloss<-"))
setGeneric("probloss<-", function(object, value)
    standardGeneric("probloss<-"))
setGeneric("probnorm<-", function(object, value)
    standardGeneric("probnorm<-"))
setGeneric("probgain<-", function(object, value)
    standardGeneric("probgain<-"))
setGeneric("probamp<-", function(object, value)
    standardGeneric("probamp<-"))
