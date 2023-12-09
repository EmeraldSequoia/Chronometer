//
//  ECAstronomyCache.h
//  Emerald Chronometer
//
//  Created by Steve Pucci on April 30 2009
//  Copyright Emerald Sequoia 2009. All rights reserved.
//

#include "Constants.h"
#include "ECAstronomy.h"
#include "ECAstronomyCache.h"

#ifdef STANDALONE
#include <stdio.h>
#include <math.h>
#include <assert.h>
#endif

static ECAstroCachePool astroCachePools[2];  // By entry thread# into ECAstronomy (if location, time zone, or calculation dates are different; see reserveCachePool)

// Once we've reserved a cache pool, set up all of the caches in that cache pool with the right parameters, bumping up the global flag
// if we don't match the cache in use
void setupGlobalCacheFlag(ECAstroCachePool *cachePool,
			  double 	   observerLatitude,
			  double 	   observerLongitude,
			  bool   	   runningBackward,
			  int              tzOffsetSeconds) {
    if (observerLatitude != cachePool->observerLatitude ||
	observerLongitude != cachePool->observerLongitude ||
	runningBackward != cachePool->runningBackward ||
	tzOffsetSeconds != cachePool->tzOffsetSeconds) {
	cachePool->observerLatitude = observerLatitude;
	cachePool->observerLongitude = observerLongitude;
	cachePool->runningBackward = runningBackward;
	cachePool->tzOffsetSeconds = tzOffsetSeconds;
	cachePool->currentGlobalCacheFlag++;
    }
}

void reinitializeECAstroCache(ECAstroCache *valueCache) {
    valueCache->currentFlag = 1;
    unsigned int *p = valueCache->cacheSlotValidFlag;
    unsigned int *end = p + numCacheSlots;
    while (p < end) {
	*p++ = 0;
    }
}

// Set the given value cache active, and return the previously active cache
// so it can be popped to later.  If dateInterval isn't sufficiently
// close to cached value, invalidate the cache.
ECAstroCache *pushECAstroCacheWithSlopInPool(ECAstroCachePool *cachePool,
					     ECAstroCache     *valueCache,
					     NSTimeInterval   dateInterval,
					     NSTimeInterval   slop) {
    assert(!isnan(dateInterval));
    ECAstroCache *oldCache = cachePool->currentCache;
    cachePool->currentCache = valueCache;
    if (valueCache) {
	valueCache->astroSlop = slop;
    } else {
	return oldCache;
    }
    if (valueCache->currentFlag == 0) {
	// The only time this state occurs is before ever calling this function, so initialize here
	valueCache->currentFlag = 1;
    }
    if (valueCache->globalValidFlag != cachePool->currentGlobalCacheFlag) {
	valueCache->globalValidFlag = cachePool->currentGlobalCacheFlag;
	goto invalid;
    } else if (isnan(dateInterval)) {
	if (!isnan(valueCache->dateInterval)) {
	    goto invalid;
	}
    } else if (isnan(valueCache->dateInterval)) {
	goto invalid;
    } else if (fabs(dateInterval - valueCache->dateInterval) > slop) {
	goto invalid;
    }
    return oldCache;
 invalid:
    if (valueCache->currentFlag == 0xffffffff) {  // this won't happen very often :-)
	reinitializeECAstroCache(valueCache);
    } else {
	valueCache->currentFlag++;
    }
    valueCache->dateInterval = dateInterval;
    return oldCache;
}

ECAstroCache *pushECAstroCacheInPool(ECAstroCachePool *cachePool,
				     ECAstroCache     *valueCache,
				     NSTimeInterval   dateInterval) {
    return pushECAstroCacheWithSlopInPool(cachePool, valueCache, dateInterval, ASTRO_SLOP_RAW);
}

// The given cache is presumed to still represent the correct date interval.
void popECAstroCacheToInPool(ECAstroCachePool *cachePool,
			     ECAstroCache     *valueCache) {
    cachePool->currentCache = valueCache;
}

void printCache(ECAstroCache     *valueCache,
		ECAstroCachePool *cachePool) {
    printf("\nCache at 0x%016lx: currentFlag %u, globalFlag %u (with global %u)\n",
	   (long)valueCache, valueCache->currentFlag, valueCache->globalValidFlag, cachePool->currentGlobalCacheFlag);
    for (int i = 0; i < numCacheSlots; i++) {
	printf("..%3d: %s %g\n", i, (valueCache->cacheSlotValidFlag[i] ? "OK" : "XX"), valueCache->cacheSlots[i]);
    }
}

void initializeAstroCache(void) {
    astroCachePools[0].currentGlobalCacheFlag = 1;
    astroCachePools[1].currentGlobalCacheFlag = 1;
}

void assertCacheValidForTDTCenturies(ECAstroCache *cache,
				     double       t) {
    // If cache is active, MUST store tdt in (or pull tdt from) cache before calling this routine:
    assert(!cache || (cache->cacheSlotValidFlag[tdtCenturiesSlotIndex] == cache->currentFlag && fabs(cache->cacheSlots[tdtCenturiesSlotIndex] - t) < 0.0000000000001));
}

void assertCacheValidForTDTHundredCenturies(ECAstroCache *cache,
					    double       hundredCenturiesSinceEpochTDT) {
    // If cache is active, MUST store tdt in (or pull tdt from) cache before calling this routine:
    assert(!cache || (cache->cacheSlotValidFlag[tdtHundredCenturiesSlotIndex] == cache->currentFlag && fabs(cache->cacheSlots[tdtHundredCenturiesSlotIndex] - hundredCenturiesSinceEpochTDT) < 0.00000000001));
}

ECAstroCachePool *getCachePoolForThisThread(void) {
    int cacheIndex = [NSThread isMainThread] ? 0 : 1;
    return &astroCachePools[cacheIndex];
}

void initializeCachePool(ECAstroCachePool *pool,
			 NSTimeInterval   dateInterval,
			 double           observerLatitude,
			 double           observerLongitude,
			 bool             runningBackward,
			 int              tzOffsetSeconds) {
    setupGlobalCacheFlag(pool, observerLatitude, observerLongitude, runningBackward, tzOffsetSeconds);
    if (pool->inActionButton) {
	assert(pool->currentCache);
	pushECAstroCacheInPool(pool, &pool->finalCache, dateInterval);
    } else {
	assert(!pool->currentCache);
	pushECAstroCacheInPool(pool, &pool->finalCache, dateInterval);
    }
}

void releaseCachePoolForThisThread(ECAstroCachePool *cachePool) {
    assert(cachePool == &astroCachePools[[NSThread isMainThread] ? 0 : 1]);
    assert(cachePool->currentCache);
    popECAstroCacheToInPool(cachePool, NULL);
}

void clearAllCaches(void) {
    astroCachePools[0].currentGlobalCacheFlag++;
    astroCachePools[1].currentGlobalCacheFlag++;
}

