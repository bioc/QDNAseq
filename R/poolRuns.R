#########################################################################/**
# @RdocFunction poolRuns
#
# @alias poolRuns,QDNAseqSignals,character-method
#
# @title "Pools binned read counts across samples"
#
# @synopsis
#
# \description{
#     @get "title".
# }
#
# \arguments{
#     \item{object}{A @see "QDNAseqReadCounts" or @see "QDNAseqCopyNumbers"
#         object.}
#     \item{samples}{A character vector of new sample names. Samples with
#         identical names will be pooled together. Must be the same length as
#         there are samples in \code{object}.}
#     \item{force}{Whether to force the operation even when downstream data will
#         be lost.}
# }
#
# \value{
#     Returns a @see "QDNAseqReadCounts" or @see "QDNAseqCopyNumbers" object.
# }
#
# \examples{
# data(LGG150)
# readCounts <- LGG150
# # Note: the following command will "pool" data from a single run, which
# # does not really make sense:
# pooledReadCounts <- poolRuns(readCounts, samples = "LGG150")
# }
#
# @author "IS"
#
# @keyword manip
#*/#########################################################################
setMethod("poolRuns", signature=c(object="QDNAseqSignals",
    samples="character"), definition=function(object, samples, force=FALSE) {

    if (!force && "segmented" %in% assayDataElementNames(object))
        stop("Data has already been segmented. Pooling runs will ",
            "remove segmentation (and possible calling) ",
            "results. Please specify force=TRUE, if you want this.")

    if (length(samples) != ncol(object))
        stop("Parameter samples must be a vector of equal length as there are ",
            " samples in object.")

    newsamples <- sort(unique(samples))
    if (length(newsamples) == ncol(object)) {
        sampleNames(object) <- samples
        object <- object[,order(samples)]
        return(object)
    }
    oldsamples <- sampleNames(object)

    bins <- featureData(object)
    phenodata <- pData(object)
    phenodata[, 1] <- samples
    newphenodata <- phenodata[0, ]
    if (inherits(object, "QDNAseqReadCounts")) {
        counts <- assayDataElement(object, "counts")
        newcounts <- matrix(NA_integer_,
            nrow=nrow(object), ncol=length(newsamples),
            dimnames=list(featureNames(object), newsamples))
    } else if (inherits(object, "QDNAseqCopyNumbers")) {
        copynumber <- assayDataElement(object, "copynumber")
        newcopynumber <- matrix(NA_real_,
            nrow=nrow(object), ncol=length(newsamples),
            dimnames=list(featureNames(object), newsamples))
    }

    concatenateIfNotEqual <- function(x) {
        x <- sort(unique(x))
        paste(x, collapse=";")
    }

    for (newsample in newsamples) {
        replicates <- samples == newsample
        if (inherits(object, "QDNAseqReadCounts")) {
            newcounts[, newsample] <- rowSums2(counts, cols=replicates, useNames=FALSE)
        } else if (inherits(object, "QDNAseqCopyNumbers")) {
            newcopynumber[, newsample] <- rowMeans2(copynumber, cols=replicates, useNames=FALSE)
        }
        oldphenodata <- phenodata[replicates, ]
        if ("paired.ends" %in% colnames(oldphenodata)) {
            pairedEnds <- unique(oldphenodata$paired.ends)
            if (length(pairedEnds) != 1)
                pairedEnds <- NA_real_
        }
        totalReads <- sum(oldphenodata$total.reads)
        usedReads <- sum(oldphenodata$used.reads)
        numericCols <- sapply(oldphenodata, FUN=is.numeric)
        oldphenodata[1,  numericCols] <- apply(oldphenodata[,  numericCols, drop = FALSE], MARGIN = 2L, FUN = mean)
        oldphenodata[1, !numericCols] <- apply(oldphenodata[, !numericCols, drop = FALSE], MARGIN = 2L, FUN = concatenateIfNotEqual)
        if ("paired.ends" %in% colnames(oldphenodata))
            oldphenodata[1, "paired.ends"] <- pairedEnds
        oldphenodata[1, "total.reads"] <- totalReads
        oldphenodata[1, "used.reads"] <- usedReads
        newphenodata <- rbind(newphenodata, oldphenodata[1, ], stringsAsFactors=FALSE)
    }
    rownames(newphenodata) <- newphenodata$name
    metadata <- varMetadata(object)
    metadata <- rbind(metadata, structure(data.frame(labelDescription = NA_character_), rownames = "total.reads"))
    newphenodata <- AnnotatedDataFrame(newphenodata, varMetadata=metadata)
    if (inherits(object, "QDNAseqReadCounts")) {
        storage.mode(newcounts) <- "integer"
        object2 <- new("QDNAseqReadCounts",
            bins=bins,
            counts=newcounts,
            phenodata=newphenodata)
    } else if (inherits(object, "QDNAseqCopyNumbers")) {
        object2 <- new("QDNAseqCopyNumbers",
            bins=bins,
            copynumber=newcopynumber,
            phenodata=newphenodata)
    }
    object2$expected.variance <- expectedVariance(object2)
    object2
})
