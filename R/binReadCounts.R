#########################################################################/**
# @RdocFunction binReadCounts
#
# @title "Calculate binned read counts from a set of BAM files"
#
# @synopsis
#
# \description{
#     @get "title".
# }
#
# \arguments{
#     \item{bins}{A data.frame or an @see "Biobase::AnnotatedDataFrame" object
#         containing bin annotations.}
#     \item{bamfiles}{A character vector of (BAM) file names. If NULL (default),
#         all files with extension ext, are read from directory path.}
#     \item{path}{If bamfiles is NULL, directory path to read input files from.
#         Defaults to the current working directory.}
#     \item{ext}{File name extension of input files to read, default is "bam".}
#     \item{bamnames}{An optional character vector of sample names. Defaults to
#         file names with extension ext removed.}
#     \item{phenofile}{An optional character(1) specifying a file name for
#         phenotype data.}
#     \item{chunkSize}{An optional integer specifying the chunk size (nt) by
#         which to process the bam file.}
#     \item{cache}{Whether to read and write intermediate cache files, which
#         speeds up subsequent analyses of the same files. Requires packages
#         R.cache and digest (both available on CRAN) to be installed. Defaults
#         to getOption("QDNAseq::cache", FALSE).}
#     \item{force}{When using the cache, whether to force reading input data
#         from the BAM files even when an intermediate cache file is present.}
#     \item{isPaired}{A logical(1) indicating whether unpaired (FALSE), paired
#         (TRUE), or any (NA, default) read should be returned.}
#     \item{isProperPair}{A logical(1) indicating whether improperly paired
#         (FALSE), properly paired (TRUE), or any (NA, default) read should be
#         returned. A properly paired read is defined by the alignment algorithm
#         and might,    e.g., represent reads aligning to identical reference
#         sequences and with a specified distance.}
#     \item{isUnmappedQuery}{A logical(1) indicating whether unmapped
#         (TRUE), mapped (FALSE, default), or any (NA) read should be returned.}
#     \item{hasUnmappedMate}{A logical(1) indicating whether reads with mapped
#         (FALSE), unmapped (TRUE), or any (NA, default) mate should be
#         returned.}
#     \item{isMinusStrand}{A logical(1) indicating whether reads aligned to
#         the plus (FALSE), minus (TRUE), or any (NA, default) strand should be
#         returned.}
#     \item{isMateMinusStrand}{A logical(1) indicating whether mate reads
#         aligned to the plus (FALSE), minus (TRUE), or any (NA, default) strand
#         should be returned.}
#     \item{isFirstMateRead}{A logical(1) indicating whether the first mate
#         read should be returned (TRUE) or not (FALSE), or whether mate read
#         number should be ignored (NA, default).}
#     \item{isSecondMateRead}{A logical(1) indicating whether the second mate
#         read should be returned (TRUE) or not (FALSE), or whether mate read
#         number
#         should be ignored (NA, default).}
#     \item{isSecondaryAlignment}{A logical(1) indicating whether alignments
#         that are primary (FALSE), are not primary (TRUE) or whose primary
#         status does not matter (NA, default) should be returned. A non-primary
#         alignment ("secondary alignment" in the SAM specification) might
#         result when a read aligns to multiple locations. One alignment is
#         designated as primary and has this flag set to FALSE; the remainder,
#         for which this flag is TRUE, are designated by the aligner as
#         secondary.}
#     \item{isNotPassingQualityControls}{A logical(1) indicating whether
#         reads passing quality controls (FALSE, default), reads not passing
#         quality controls (TRUE), or any (NA) read should be returned.}
#     \item{isDuplicate}{A logical(1) indicating that un-duplicated
#         (FALSE, default), duplicated (TRUE), or any (NA) reads should be
#         returned. 'Duplicated' reads may represent PCR or optical duplicates.}
#     \item{minMapq}{If quality scores exists, the minimum quality score
#         required in order to keep a read, otherwise all reads are kept.}
#     \item{pairedEnds}{A boolean value or vector specifying whether the BAM
#         files contain paired-end data or not. Only affects the calculation of
#         the expected variance.}
#     \item{verbose}{If @TRUE, verbose messages are produced.}
# }
#
# \value{
#     Returns a @see "QDNAseqReadCounts" object with assay data element
#     \code{counts} containing the binned read counts as non-negative @integers.
# }
#
# \examples{
# \dontrun{# read all files from the current directory with names ending in .bam
# bins <- getBinAnnotations(15)
# readCounts <- binReadCounts(bins)
# }
# }
#
# @author "IS,DS"
#
# @keyword IO
# @keyword file
#*/#########################################################################
binReadCounts <- function(bins, bamfiles=NULL, path=NULL, ext='bam',
    bamnames=NULL, phenofile=NULL, chunkSize=NULL,
    cache=getOption("QDNAseq::cache", FALSE), force=!cache,
    isPaired=NA, isProperPair=NA,
    isUnmappedQuery=FALSE, hasUnmappedMate=NA,
    isMinusStrand=NA, isMateMinusStrand=NA,
    isFirstMateRead=NA, isSecondMateRead=NA,
    isSecondaryAlignment=NA,
    isNotPassingQualityControls=FALSE,
    isDuplicate=FALSE,
    minMapq=37,
    pairedEnds=NULL,
    verbose=getOption("QDNAseq::verbose", TRUE)) {

    oopts <- options("QDNAseq::verbose"=verbose)
    on.exit(options(oopts))

    if (is.null(bamfiles))
        bamfiles <- list.files(ifelse(is.null(path), '.', path),
            pattern=sprintf('%s$', ext), full.names=TRUE)
    if (length(bamfiles) == 0L)
        stop('No files to process.')
    if (is.null(bamnames)) {
        bamnames <- basename(bamfiles)
        bamnames <- sub(sprintf('[\\.]?%s$', ext), '', bamnames)
    } else if (length(bamfiles) != length(bamnames)) {
        stop('bamfiles and bamnames have to be of same length.')
    }
    phenodata <- data.frame(name=bamnames, row.names=bamnames,
        stringsAsFactors=FALSE)
    if (!is.null(pairedEnds) &&
        (!length(pairedEnds) %in% c(1, length(bamnames)) ||
        !is.logical(pairedEnds))) {

        stop("Parameter pairedEnds has to be a logical vector with a ",
            "length of either 1 or the number of BAM files.")
    }
    if (!is.null(phenofile)) {
        pdata <- read.table(phenofile, header=TRUE, sep='\t', as.is=TRUE,
            row.names=1L, stringsAsFactors=FALSE)
        phenodata <- cbind(phenodata, pdata[rownames(phenodata), , drop=FALSE])
    }

    if (inherits(bins, "data.frame"))
        bins <- AnnotatedDataFrame(bins)

    counts <- matrix(NA_integer_, nrow=nrow(bins), ncol=length(bamnames),
        dimnames=list(featureNames(bins), bamnames))
    for (i in seq_along(bamfiles)) {
        vmsg("    ", bamnames[i], " (", i, " of ", length(bamfiles), "): ",
            appendLF=FALSE)
        if (!is.null(chunkSize)) {
            counts[, i] <- .binReadCountsPerChunk(bins=bins,
                bamfile=bamfiles[i], chunkSize=chunkSize,
                cache=cache, force=force, isPaired=isPaired,
                isProperPair=isProperPair, isUnmappedQuery=isUnmappedQuery,
                hasUnmappedMate=hasUnmappedMate, isMinusStrand=isMinusStrand,
                isMateMinusStrand=isMateMinusStrand,
                isFirstMateRead=isFirstMateRead, isSecondMateRead=isSecondMateRead,
                isSecondaryAlignment=isSecondaryAlignment,
                isNotPassingQualityControls=isNotPassingQualityControls,
                isDuplicate=isDuplicate,
                minMapq=minMapq)
        } else {
        counts[, i] <- .binReadCountsPerSample(bins=bins,
                bamfile=bamfiles[i], cache=cache, force=force,
                isPaired=isPaired, isProperPair=isProperPair,
                isUnmappedQuery=isUnmappedQuery, hasUnmappedMate=hasUnmappedMate,
                isMinusStrand=isMinusStrand, isMateMinusStrand=isMateMinusStrand,
                isFirstMateRead=isFirstMateRead, isSecondMateRead=isSecondMateRead,
                isSecondaryAlignment=isSecondaryAlignment,
                isNotPassingQualityControls=isNotPassingQualityControls,
                isDuplicate=isDuplicate,
                minMapq=minMapq)
        }
        vmsg()
        gc(FALSE)

    }

    if (!is.null(pairedEnds))
        phenodata$paired.ends <- pairedEnds
    condition <- binsToUse(bins)
    phenodata$total.reads <- colSums(counts)
    phenodata$used.reads <- colSums2(counts, rows=condition, useNames=FALSE)

    object <- new('QDNAseqReadCounts', bins=bins, counts=counts,
        phenodata=phenodata)
    object$expected.variance <- expectedVariance(object)
    object
}



.binReadCountsPerChunk <- function(bins, bamfile, chunkSize, cache, force,
        isPaired, isProperPair, isUnmappedQuery, hasUnmappedMate,
        isMinusStrand, isMateMinusStrand, isFirstMateRead, isSecondMateRead,
        isSecondaryAlignment, isNotPassingQualityControls, isDuplicate, minMapq,
        verbose=getOption("QDNAseq::verbose", TRUE)) {

    assert_future_version() ## Until future.apply (>= 1.9.0) is on CRAN

    binSize <- (bins$end[1L]-bins$start[1L]+1)/1000

    bamfile <- normalizePath(bamfile)
    fullname <- sub('\\.[^.]*$', '', basename(bamfile))

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Check for cached results
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    vmsg('extracting reads ...', appendLF=TRUE)
    flag <- scanBamFlag(isPaired=isPaired,
            isProperPair=isProperPair, isUnmappedQuery=isUnmappedQuery,
            hasUnmappedMate=hasUnmappedMate, isMinusStrand=isMinusStrand,
            isMateMinusStrand=isMateMinusStrand,
            isFirstMateRead=isFirstMateRead,
            isSecondMateRead=isSecondMateRead,
            isSecondaryAlignment=isSecondaryAlignment,
            isNotPassingQualityControls=isNotPassingQualityControls,
            isDuplicate=isDuplicate)

# Fetch info from header
    bamHeader <- scanBamHeader(bamfile)

# targets named vector
    targets <- bamHeader[[1]][1]$targets

# determine chunk size
    if (!is.numeric(chunkSize))
        chunkSize <- max(targets) + 1

    countsPerTarget <- future_lapply(names(targets), FUN=function(seqName) {
        readCounts <- integer(length=nrow(bins))
        seqNameI <- sub('chr', '', seqName)
        for (chunk in 1:ceiling(targets[seqName] / chunkSize)) {
            chunkStart <- (chunk - 1) * chunkSize + 1
            chunkEnd <- chunk * chunkSize + 1
            params <- ScanBamParam(flag=flag,
                what=c('rname', 'pos', 'mapq'),
                which=GRanges(seqName, IRanges(chunkStart, chunkEnd)))
            reads <- scanBam(bamfile, param=params)
            reads <- reads[[1L]]

# Filter by read quality scores?
            hasMapq <- any(is.finite(reads[['mapq']]))
            if (hasMapq) {
                keep <- which(reads[['mapq']] >= minMapq)
                reads <- lapply(reads, FUN=function(x) x[keep])
            }

            hits <- list()
            hits[[seqNameI]] <- reads[['pos']]

            chunkName <- paste(seqName, chunkStart, chunkEnd, sep=":")
            vmsg(paste('binning chunk -', chunkName, sep=" "), appendLF=TRUE)

            keep <- which(
                bins$chromosome == seqNameI &
                bins$start >= chunkStart &
                bins$end <= chunkEnd
            )

            if (length(keep) == 0L)
                next

            chromosomeBreaks <- c(bins$start[keep], max(bins$end[keep]) + 1)
            counts <- binCounts(hits[[seqNameI]], bx=chromosomeBreaks)
            readCounts[keep] <- readCounts[keep] + counts
        }
        readCounts
    })
    Reduce('+', countsPerTarget)
}

.binReadCountsPerSample <- function(bins, bamfile, cache, force,
    isPaired, isProperPair, isUnmappedQuery, hasUnmappedMate,
    isMinusStrand, isMateMinusStrand, isFirstMateRead, isSecondMateRead,
    isSecondaryAlignment, isNotPassingQualityControls, isDuplicate, minMapq) {

    ## purge outdated files from the cache
    QDNAseqCacheKeyVersion <- "0.6.0"
    if (cache) {
        cachePath <- normalizePath(R.cache::getCachePath(dirs=c("QDNAseq",
            QDNAseqCacheKeyVersion)))
        oldCaches <- setdiff(list.files(dirname(cachePath), full.names=TRUE),
            cachePath)
        sapply(oldCaches, FUN=unlink, recursive=TRUE)
    }

    binSize <- (bins$end[1L]-bins$start[1L]+1)/1000

    bamfile <- normalizePath(bamfile)
    fullname <- sub('\\.[^.]*$', '', basename(bamfile))

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    # Check for cached results
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    readCountCacheKey <- list(bamfile=bamfile, filesize=file.info(bamfile)$size,
        isPaired=isPaired, isProperPair=isProperPair,
        isUnmappedQuery=isUnmappedQuery, hasUnmappedMate=hasUnmappedMate,
        isMinusStrand=isMinusStrand, isMateMinusStrand=isMateMinusStrand,
        isFirstMateRead=isFirstMateRead, isSecondMateRead=isSecondMateRead,
        isSecondaryAlignment=isSecondaryAlignment,
        isNotPassingQualityControls=isNotPassingQualityControls,
        isDuplicate=isDuplicate, minMapq=minMapq, binSize=binSize)
    readCountCacheDir <- c('QDNAseq', QDNAseqCacheKeyVersion, 'readCounts')
    readCountCacheSuffix <- paste('.', fullname, '.', binSize, 'kbp', sep='')
    if (!force) {
        readCounts <- R.cache::loadCache(key=readCountCacheKey, sources=bamfile,
            suffix=readCountCacheSuffix, dirs=readCountCacheDir)
        if (!is.null(readCounts)) {
            vmsg('binned read counts loaded from cache', appendLF=FALSE)
            return(readCounts)
        }
    }


    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    # Retrieve counts per chromosome
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    readCacheKey <- list(bamfile=bamfile, filesize=file.info(bamfile)$size,
        isPaired=isPaired, isProperPair=isProperPair,
        isUnmappedQuery=isUnmappedQuery, hasUnmappedMate=hasUnmappedMate,
        isMinusStrand=isMinusStrand, isMateMinusStrand=isMateMinusStrand,
        isFirstMateRead=isFirstMateRead, isSecondMateRead=isSecondMateRead,
        isSecondaryAlignment=isSecondaryAlignment,
        isNotPassingQualityControls=isNotPassingQualityControls,
        isDuplicate=isDuplicate, minMapq=minMapq)
    readCacheDir <- c('QDNAseq', QDNAseqCacheKeyVersion, 'reads')
    readCacheSuffix <- paste('.', fullname, sep='')
    hits <- NULL
    if (!force)
        hits <- R.cache::loadCache(key=readCacheKey, sources=bamfile,
            suffix=readCacheSuffix, dirs=readCacheDir)

    if (!is.null(hits)) {
        vmsg('reads loaded from cache,', appendLF=FALSE)
    } else {
        vmsg('extracting reads ...', appendLF=FALSE)
        flag <- scanBamFlag(isPaired=isPaired,
            isProperPair=isProperPair, isUnmappedQuery=isUnmappedQuery,
            hasUnmappedMate=hasUnmappedMate, isMinusStrand=isMinusStrand,
            isMateMinusStrand=isMateMinusStrand,
            isFirstMateRead=isFirstMateRead,
            isSecondMateRead=isSecondMateRead,
            isSecondaryAlignment=isSecondaryAlignment,
            isNotPassingQualityControls=isNotPassingQualityControls,
            isDuplicate=isDuplicate)
        params <- ScanBamParam(flag=flag, what=c('rname', 'pos', 'mapq'))
        reads <- scanBam(bamfile, param=params)
        reads <- reads[[1L]]

        # Filter by read quality scores?
        hasMapq <- any(is.finite(reads[['mapq']]))
        if (hasMapq) {
            keep <- which(reads[['mapq']] >= minMapq)
            reads <- lapply(reads, FUN=function(x) x[keep])
        }

        # Drop quality scores - not needed anymore
        reads[['mapq']] <- NULL

        # Sort counts by chromosome
        hits <- list()
        chrs <- unique(reads[['rname']])
        for (chr in chrs) {
            keep <- which(reads[['rname']] == chr)
            hits[[chr]] <- reads[['pos']][keep]
        }
        names(hits) <- sub('^chr', '', names(hits))
        rm(list=c('reads'))
        gc(FALSE)

        if (cache) {
            vmsg(' saving in cache ...', appendLF=FALSE)
            R.cache::saveCache(hits, key=readCacheKey, sources=bamfile,
                suffix=readCacheSuffix, dirs=readCacheDir, compress=TRUE)
        }
    }


    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    # Bin by chromosome
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    vmsg(' binning ...', appendLF=FALSE)
    readCounts <- integer(length=nrow(bins))
    for (chromosome in names(hits)) {
        keep <- which(bins$chromosome == chromosome);

        ## No bins for this chromosome?
        if (length(keep) == 0L)
            next

        chromosomeBreaks <- c(bins$start[keep], max(bins$end[keep]) + 1)
        counts <- binCounts(hits[[chromosome]], bx=chromosomeBreaks)
        readCounts[keep] <- readCounts[keep] + counts

        ## Not needed anymore
        chromosomeBreaks <- keep <- counts <- NULL
    }
    ## Not needed anymore
    rm(list=c("hits"))
    gc(FALSE)


    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    # Store results in cache
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    if (cache) {
        vmsg(' saving in cache ...', appendLF=FALSE)
        R.cache::saveCache(readCounts, key=readCountCacheKey, sources=bamfile,
            suffix=readCountCacheSuffix, dirs=readCountCacheDir, compress=TRUE)
    }

    readCounts
}

importReadCounts <- function(counts, bins, phenodata=NULL) {
    if (inherits(bins, "data.frame"))
        bins <- AnnotatedDataFrame(bins)
    if (inherits(phenodata, "data.frame"))
        phenodata <- AnnotatedDataFrame(phenodata)
    if (is.null(phenodata)) {
        condition <- binsToUse(bins)
        phenodata <- AnnotatedDataFrame(
                                        data.frame(
                                                   sampleNames=colnames(counts),
                                                   total.reads=colSums(counts),
                                                   used.reads=colSums2(counts, rows=condition, useNames=FALSE),
                                                   stringsAsFactors=FALSE
                                                   ))
    }
    object <- new('QDNAseqReadCounts', bins=bins, counts=counts, phenodata=phenodata)
    return(object)
}
