#########################################################################/**
# @RdocFunction callBins
#
# @alias callBins,QDNAseqCopyNumbers-method
#
# @title "Call aberrations from segmented copy number data"
#
# @synopsis
#
# \description{
#     @get "title".
# }
#
# \arguments{
#     \item{object}{An object of class QDNAseqCopyNumbers}
#     \item{organism}{Either \dQuote{human} or \dQuote{other}, see manual page
#         for @see "CGHcall::CGHcall" for more details. This is only used for
#         chromosome arm information when \dQuote{prior} is set to \dQuote{all}
#         or \dQuote{auto} (and samplesize > 20). Ignored when \code{method} is
#         not \dQuote{CGHcall}.}
#     \item{method}{Calling method to use. Options currently implemented are:
#         \dQuote{CGHcall} or \dQuote{cutoff}.}
#     \item{cutoffs}{When method=\dQuote{cutoff}, a numeric vector of
#         (log2-transformed) thresholds to use for calling. At least one
#         positive and one negative value must be provided. The smallest
#         positive value is used as the cutoff for calling gains, and the
#         negative value closest to zero is used as the cutoff for losses. If a
#         second positive value is provided, it is used as the cutoff for
#         amplifications. And if a second negative value is provided, it is used
#         as the cutoff for homozygous deletions.}
#     \item{...}{Additional arguments passed to @see "CGHcall::CGHcall".}
#%     \item{verbose}{If @TRUE, verbose messages are produced.}
# }
#
# \details{
#     By default, chromosomal aberrations are called with \pkg{CGHcall}. It has
#     been developed for the analysis of series of cancer samples, and uses a
#     model that contains both gains and losses. If used on a single sample, or
#     especially only on a subset of chromosomes, or especially on a single
#     non-cancer sample, it may fail, but method \dQuote{cutoff} can be used
#     instead.
#
#     When using method \dQuote{cutoff}, the default values assume a uniform
#     cell population and correspond to thresholds of (assuming a diploid
#     genome) 0.5, 1.5, 2.5, and 10 copies to distinguish between homozygous
#     deletions, (hemizygous) losses, normal copy number, gains, and
#     amplifications, respectively. When using with cancer samples, these values
#     might require adjustments to account for tumor cell percentage.
# }
#
# \value{
#     Returns an object of class @see "QDNAseqCopyNumbers" with calling
#     results added.
# }
#
# \examples{
# data(LGG150)
# readCounts <- LGG150
# readCountsFiltered <- applyFilters(readCounts)
# readCountsFiltered <- estimateCorrection(readCountsFiltered)
# copyNumbers <- correctBins(readCountsFiltered)
# copyNumbersNormalized <- normalizeBins(copyNumbers)
# copyNumbersSmooth <- smoothOutlierBins(copyNumbersNormalized)
# copyNumbersSegmented <- segmentBins(copyNumbersSmooth)
# copyNumbersSegmented <- normalizeSegmentedBins(copyNumbersSegmented)
# copyNumbersCalled <- callBins(copyNumbersSegmented)
# }
#
# @author "IS"
#
# \seealso{
#     Internally, @see "CGHcall::CGHcall" and @see "CGHcall::ExpandCGHcall" of
#     the \pkg{CGHcall} package are used when method=\dQuote{CGHcall}.
# }
#
# @keyword manip
#*/#########################################################################
setMethod('callBins', signature=c(object='QDNAseqCopyNumbers'),
    definition=function(object, organism=c("human", "other"),
    method=c("CGHcall", "cutoff"),
    cutoffs=log2(c(deletion=0.5, loss=1.5, gain=2.5, amplification=10) / 2),
    ..., verbose = getOption("QDNAseq::verbose", TRUE)) {

    oopts <- options("QDNAseq::verbose"=verbose)
    on.exit(options(oopts))
    
    method <- match.arg(method)
    if (method == "CGHcall") {
        ## Mark van de Wiel confirms that CGHcall::CGHcall() assumes (=requires)
        ## CNs on the *log* scale. /IS (private email 'Log and non-positives'
        ## on 2013-12-18 between IS and HB).
        organism <- match.arg(organism)
        if (organism == "human") {
            chrs <- fData(object)$chromosome[binsToUse(object)]
            human <- chrs %in% c(1:22, "X", "Y", "MT")
            if (any(!human)) {
                warning(paste0("Non-human chromosome names detected:\n",
                    paste(unique(chrs[!human]), collapse=", "), ".\n",
                    "Passing 'organism=\"other\"' to CGHcall()."))
                organism <- "other"
                seg <- makeCgh(object, chromosomeReplacements="auto")
            } else {
                seg <- makeCgh(object)
            }
        } else {
            seg <- makeCgh(object, chromosomeReplacements="auto")
        }
        tryCatch({
            ## NOTE: CGHcall::CGHcall() produces warnings on "Recycling array
            ##       of length 1 in vector-array arithmetic is deprecated.
            ##       Use c() or as.vector() instead."
            ## NOTE: CGHcall::CGHcall() produces message():s and stdout output.
            suppressVerbose({
                listcall <- CGHcall(seg, organism=organism, ...)
            }, suppress = !verbose)
        }, error=function(e) {
            stop("Command CGHcall() returned the following error message:\n",
                e, "Please contact maintainer of package CGHcall: ",
                maintainer("CGHcall"), call.=FALSE)
        })
        tryCatch({
            ## NOTE: CGHcall::ExpandCGHcall() produces message():s.
            suppressVerbose({
                cgh <- ExpandCGHcall(listcall, seg)
            }, suppress = !verbose)
        }, error=function(e) {
            stop("Command ExpandCGHcall() returned the following error ",
                "message:\n", e,
                "Please contact maintainer of package CGHcall: ",
                maintainer("CGHcall"), call.=FALSE)
        })
        calls(object) <- calls(cgh)
        if ('probdloss' %in% assayDataElementNames(cgh)) {
            probdloss(object) <- probdloss(cgh)
        } else {
            if ('probdloss' %in% assayDataElementNames(object))
                probdloss(object) <- NULL
        }
        probloss(object) <- probloss(cgh)
        probnorm(object) <- probnorm(cgh)
        probgain(object) <- probgain(cgh)
        if ('probamp' %in% assayDataElementNames(cgh)) {
            probamp(object) <- probamp(cgh)
        } else {
            if ('probamp' %in% assayDataElementNames(object))
                probamp(object) <- NULL
        }
    } else if (method == "cutoff") {
        if (!is.numeric(cutoffs))
            stop("Parameter cutoff must be a numeric vector.")
        cutoffLosses <- sort(cutoffs[cutoffs < 0], decreasing=TRUE)
        cutoffGains <- sort(cutoffs[cutoffs > 0])
        if (is.na(cutoffLosses[1]) || is.na(cutoffGains[1]))
            stop("Parameter cutoff must contain at least one positive and one ",
                "negative value, to be used as cutoffs for gains and losses, ",
                "respectively.")
        vmsg("Calling aberrations with the following cutoffs:")
        if (!is.na(cutoffLosses[2]))
            vmsg("homozygous deletion < ", round(cutoffLosses[2], digits=2),
                " < ", appendLF=FALSE)
        vmsg("loss < ", round(cutoffLosses[1], digits=2), " < normal < ",
            round(cutoffGains[1], digits=2), " gain", appendLF=FALSE)
        if (!is.na(cutoffGains[3])) {
            vmsg(" < ", round(cutoffGains[2], digits=2), " < duplication",
                appendLF=FALSE)
            vmsg(" < ", round(cutoffGains[3], digits=2), " < amplification",
                appendLF=FALSE)
        } else {
            if (!is.na(cutoffGains[2]))
                vmsg(" < ", round(cutoffGains[2], digits=2), " < amplification",
                    appendLF=FALSE)
        }
        vmsg()
        segmentedMatrix <- log2adhoc(assayDataElement(object, "segmented"))
        ## multiplication with 1L turns logical values into integers
        ## multiplication with 1 turns logical values into numeric ones
        callsMatrix <- (segmentedMatrix > cutoffGains[1]) * 1L
        callsMatrix[segmentedMatrix < cutoffLosses[1]] <- -1L
        if (!is.na(cutoffLosses[2])) {
            callsMatrix[segmentedMatrix < cutoffLosses[2]] <- -2L
            probdloss(object) <- (callsMatrix == -2) * 1
        } else {
            if ("probdloss" %in% assayDataElementNames(object))
                probdloss(object) <- NULL
        }
        if (!is.na(cutoffGains[3])) {
            callsMatrix[segmentedMatrix > cutoffGains[2]] <- 2L
            assayDataElement(object, "probdgain") <- (callsMatrix == 2) * 1
            callsMatrix[segmentedMatrix > cutoffGains[3]] <- 3L
            probamp(object) <- (callsMatrix == 3) * 1
        } else {
            if (!is.na(cutoffGains[2])) {
                callsMatrix[segmentedMatrix > cutoffGains[2]] <- 2L
                probamp(object) <- (callsMatrix == 2) * 1
            } else {
                    if ("probamp" %in% assayDataElementNames(object))
                    probamp(object) <- NULL
                #if ("probdgain" %in% assayDataElementNames(object))
                #    assayDataElement(object, "probdgain") <- NULL
            }
        }
        calls(object) <- callsMatrix
        probloss(object) <- (callsMatrix == -1) * 1
        probnorm(object) <- (callsMatrix == 0) * 1
        probgain(object) <- (callsMatrix == 1) * 1
    }
    object
})

# Experimental functions below!!!
# Assess deletion, loss, gain, amplification

betterCall <- function(obj) {
    cn <- assayDataElement(obj, "copynumber")[,1]
    seg <- log2adhoc(assayDataElement(obj, "segmented")[,1])
    sd <- sdDiffTrim(cn, na.rm=TRUE)
    calls <- rep(0, times=length(seg))
    pval <- 0.01
    # Duplication 
    dupL <- qnorm(pval, mean=1, sd=sd, lower.tail=TRUE)
    dupU <- qnorm(pval, mean=1, sd=sd, lower.tail=FALSE)
    dup <- seg >= dupL & seg <= dupU
    calls[dup] <- 2
    vmsg(paste("dup:", dupL, dupU, sep="\t"))
    # Gain
    gainL <- qnorm(pval, mean=log2(3/2), sd=sd, lower.tail=TRUE)
    gainU <- qnorm(pval, mean=log2(3/2), sd=sd, lower.tail=FALSE)
    gain <- seg >= gainL & seg < gainU
    calls[gain] <- 1
    vmsg(paste("gain:", gainL, gainU, sep="\t"))
    # Loss
    lossL <- qnorm(pval, mean=-1, sd=sd, lower.tail=TRUE)
    lossU <- qnorm(pval, mean=-1, sd=sd, lower.tail=FALSE)
    loss <- seg >= lossL & seg <= lossU
    calls[loss] <- -1
    vmsg(paste("loss:", lossL, lossU, sep="\t"))
    # Amp 
    amp <- seg > dupU
    calls[amp] <- 3
    # Norm 
    nrm <- seg >= lossU & seg <= gainL
    calls[nrm] <- 0
    # Deletion
    del <- seg < lossL
    calls[del] <- -2
    return(calls)
}
