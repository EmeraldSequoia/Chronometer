//
//  ECVirtualMachineOps.m
//  Emerald Chronometer
//
//  Created by Steve Pucci 5/2008.
//  Copyright Emerald Sequoia LLC 2008. All rights reserved.
//

#import "Parser/EBVirtualMachine.h"
#include "Parser/EBVirtualMachinePvt.h"
#include "Parser/EBVirtualMachineOps.h"
#import "Constants.h"
#import "ECGlobals.h"
#import "ECPartController.h"
#import "ECWatchTime.h"
#import "ECAstronomy.h"
#import "ECLocationManager.h"
#import "ECDemo.h"
#import "ECWatchEnvironment.h"
#import "ChronometerAppDelegate.h"
#import "ECGLWatch.h"
#import "ECAudio.h"
#import "ECTS.h"
#import "ECOptions.h"
#import "ECFactoryUI.h"
#import "TSTime.h"

static void
printAngle(double      angle,
	   const char *description) {
    int sign = angle < 0 ? -1 : 1;
    double absAngle = fabs(angle);
    int degrees = sign * (int)(((long long int)floor(absAngle * 180/M_PI)));
    int arcMinutes = (int)(((long long int)floor(absAngle * 180/M_PI * 60)) % 60);
    int arcSeconds = (int)(((long long int)floor(absAngle * 180/M_PI * 3600)) % 60);
    int arcSecondHundredths = (int)(((long long int)floor(absAngle * 180/M_PI * 360000)) % 100);
    int hours = sign * (int)(((long long int)floor(absAngle * 12/M_PI)));
    int minutes = (int)(((long long int)floor(absAngle * 12/M_PI * 60)) % 60);
    int seconds = (int)(((long long int)floor(absAngle * 12/M_PI * 3600)) % 60);
    int secondHundredths = (int)(((long long int)floor(absAngle * 12/M_PI * 360000)) % 100);
    printf("%16.8fr %16.8fd %5do%02d'%02d.%02d\" %16.8fh %5dh%02dm%02d.%02ds  %s\n",
	   angle,
	   angle * 180 / M_PI,
	   degrees,
	   arcMinutes,
	   arcSeconds,
	   arcSecondHundredths,
	   angle * 12 / M_PI,
	   hours,
	   minutes,
	   seconds,
	   secondHundredths,
	   description);
}

// How many time units are in each second, so you can write 40.0 * seconds() for 40 seconds
EBVM_OP0(seconds)
{
    return 1.0;
}

// How many time units are in each minute, so you can write 40.0 * minutes() for 40 minutes
EBVM_OP0(minutes)
{
    return 60.0;
}

// How many time units are in each hour, so you can write 5.0 * hours() for 5 hours
EBVM_OP0(hours)
{
    return 3600.0;
}

// How many time units are in each day, so you can write 5.0 * days() for 5 days
EBVM_OP0(days)
{
    return 24.0 * 3600.0;
}

// How many time units are in each year, so you can write 5.0 * years() for 5 years
EBVM_OP0(years)
{
    return 24.0 * 3600.0 * 365.242191;
}

// NOTE from steve:  These methods really ought to go into the base parser VMOP file...

// 12.6789 % 10 => 2.6789
EBVM_OP2(fmod, arg1, arg2)
{
    return EC_fmod(arg1, arg2);
}

// abs(-12.6789) => 12.6789
EBVM_OP1(abs, arg1)
{
    return fabs(arg1);
}

// sqrt(2) => 1.414
EBVM_OP1(sqrt, arg1)
{
    return sqrt(arg1);
}

// sin(12.6789) => 0.219486
EBVM_OP1(sin, arg1)
{
    return sin(arg1);
}

// cos(12.6789) => ?
EBVM_OP1(cos, arg1)
{
    return cos(arg1);
}

// tan(12.6789) => ??
EBVM_OP1(tan, arg1)
{
    return tan(arg1);
}

// asin(12.6789) => 0.219486
EBVM_OP1(asin, arg1)
{
    return asin(arg1);
}

// acos(12.6789) => ?
EBVM_OP1(acos, arg1)
{
    return acos(arg1);
}

// atan(12.6789) => ??
EBVM_OP1(atan, arg1)
{
    return atan(arg1);
}

// log(12.6789) => ??
EBVM_OP1(log, arg1)
{
    return log10(arg1);
}

// ln(12.6789) => ??
EBVM_OP1(ln, arg1)
{
    return log(arg1);
}

// ntp skew value
EBVM_OP0(skew)
{
    return [TSTime skew];
}

EBVM_OP0(skewAngle)
{
    return (2 * M_PI / 60) * [TSTime skew];
}

EBVM_OP0(reSync)
{
    [ECTS reSync];
    return 0;
}

EBVM_OP0(stopSync)
{
    [ECTS stopNTP];
    return 0;
}

EBVM_OP0(ECTSActive)
{
    return [ECTS active];
}

EBVM_OP0(ECTSynched)
{
    return [ECTS synched];
}

EBVM_OP0(ECTSRunning)
{
    return [ECTS running];
}

EBVM_OP0(timeIndicatorAngle)
{
    /* indicator wheel color angles:
     green:      0, pi/2
     yellow:     pi, 3*pi/2
     black:      (2*n+1)*pi/4
     */     
    switch ([ECTS indicatorState]) {
	case ECTSGood:					   return M_PI/2;
        case ECTSWorkingGood:	                           return ((int)([NSDate timeIntervalSinceReferenceDate]/ECStatusIndicatorBlinkRate) % 2) ? M_PI/2 : M_PI/4;
	case ECTSWorkingUncertain:                         return ((int)([NSDate timeIntervalSinceReferenceDate]/ECStatusIndicatorBlinkRate) % 2) ? M_PI   : 3*M_PI/4;
	case ECTSUncertain:				   return M_PI;
	case ECTSOFF:					   return M_PI/4;
	case ECTSFailed:				   return M_PI;
	case ECTSCanceled:				   return M_PI;
	default:		    assert(false);	   return M_PI/4;
    }
}

EBVM_OP0(timeIndicatorColor)
{
    if ([ECOptions purpleZone]) {
	return ECmagenta;
    }
    switch ([ECTS indicatorState]) {
	case ECTSGood:					   return ECgreen;
        case ECTSWorkingGood:	                           return ((int)([NSDate timeIntervalSinceReferenceDate]/ECStatusIndicatorBlinkRate) % 2) ? ECgreen : ECblack;
	case ECTSWorkingUncertain:                         return ((int)([NSDate timeIntervalSinceReferenceDate]/ECStatusIndicatorBlinkRate) % 2) ? ECyellow: ECblack;
	case ECTSUncertain:				   return ECyellow;
	case ECTSOFF:					   return ECblack;
	case ECTSFailed:				   return ECyellow;
	case ECTSCanceled:				   return ECyellow;
	default:		    assert(false);	   return ECblack;
    }
}

// 12:35:45.9 => ??
EBVM_OP0(currentTime)
{
    return [[[virtualMachine owner] mainTime] currentTime];
}

// 12:35:45.9 => 45
EBVM_OP0(secondNumber)
{
    return [[virtualMachine owner] getIntValueFromMainTime:@selector(secondNumberUsingEnv:)];
}
EBVM_OP1(secondNumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromTimeForEnv:timerNumber watchTimeSelector:@selector(secondNumberUsingEnv:)];
}
// All angles are in radians cw from 12, based on a logical dial displaying the unit
EBVM_OP0(secondNumberAngle)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getIntValueFromMainTime:@selector(secondNumberUsingEnv:)];
}
EBVM_OP1(secondNumberAngleN, timerNumber)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getIntValueFromTimeForEnv:timerNumber watchTimeSelector:@selector(secondNumberUsingEnv:)];
}

// 12:35:45.9 => 45.9
EBVM_OP0(secondValue)
{
    return [[virtualMachine owner] getValueFromMainTime:@selector(secondValueUsingEnv:)];
}
EBVM_OP1(secondValueN, timerNumber)
{
    return [[virtualMachine owner] getValueFromTimeForEnv:timerNumber watchTimeSelector:@selector(secondValueUsingEnv:)];
}
EBVM_OP0(secondValueAngle)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getValueFromMainTime:@selector(secondValueUsingEnv:)];
}
EBVM_OP1(secondValueAngleN, timerNumber)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getValueFromTimeForEnv:timerNumber watchTimeSelector:@selector(secondValueUsingEnv:)];
}

// 12:35:45 => 35
EBVM_OP0(minuteNumber)
{
    return [[virtualMachine owner] getIntValueFromMainTime:@selector(minuteNumberUsingEnv:)];
}
EBVM_OP1(minuteNumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromTimeForEnv:timerNumber watchTimeSelector:@selector(minuteNumberUsingEnv:)];
}
EBVM_OP0(minuteNumberAngle)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getIntValueFromMainTime:@selector(minuteNumberUsingEnv:)];
}
EBVM_OP1(minuteNumberAngleN, timerNumber)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getIntValueFromTimeForEnv:timerNumber watchTimeSelector:@selector(minuteNumberUsingEnv:)];
}

// 12:35:45 => 35.75
EBVM_OP0(minuteValue)
{
    return [[virtualMachine owner] getValueFromMainTime:@selector(minuteValueUsingEnv:)];
}
EBVM_OP1(minuteValueN, timerNumber)
{
    return [[virtualMachine owner] getValueFromTimeForEnv:timerNumber watchTimeSelector:@selector(minuteValueUsingEnv:)];
}
EBVM_OP0(minuteValueAngle)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getValueFromMainTime:@selector(minuteValueUsingEnv:)];
}
EBVM_OP1(minuteValueAngleN, timerNumber)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getValueFromTimeForEnv:timerNumber watchTimeSelector:@selector(minuteValueUsingEnv:)];
}

// 13:45:00 => 1  ; 12:45:00 => 0
EBVM_OP0(hour12Number)
{
    return [[virtualMachine owner] getIntValueFromMainTime:@selector(hour12NumberUsingEnv:)];
}
EBVM_OP1(hour12NumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromTimeForEnv:timerNumber watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}
EBVM_OP0(hour12NumberAngle)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getIntValueFromMainTime:@selector(hour12NumberUsingEnv:)];
}
EBVM_OP1(hour12NumberAngleN, timerNumber)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getIntValueFromTimeForEnv:timerNumber watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}
// 12:45:00 => 12
EBVM_OP0(hour12Number12)
{
    double ret = [[virtualMachine owner] getIntValueFromMainTime:@selector(hour12NumberUsingEnv:)];
    if (ret == 0) {
	ret = 12;
    }
    return ret;
}

// 13:45:00 => 1.75
EBVM_OP0(hour12Value)
{
    return [[virtualMachine owner] getValueFromMainTime:@selector(hour12ValueUsingEnv:)];
}
EBVM_OP1(hour12ValueN, timerNumber)
{
    return [[virtualMachine owner] getValueFromTimeForEnv:timerNumber watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}
EBVM_OP0(hour12ValueAngle)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getValueFromMainTime:@selector(hour12ValueUsingEnv:)];
}
EBVM_OP1(hour12ValueAngleN, timerNumber)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getValueFromTimeForEnv:timerNumber watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}

// angle of hand on traditional Japanese wadokei clock with fixed dial
//   noon on top
//   of questionable validity in polar latitudes
EBVM_OP0(japanHourValueAngle)
{
    double now	   =  [[virtualMachine owner] getValueFromMainTime:@selector(hour24ValueUsingEnv:)];
    bool dayTime   =  [[[virtualMachine owner] mainAstro] planetIsUp:ECPlanetSun];
    double sunrise = [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithSunriseForDay) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
    double sunset  = [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithSunsetForDay) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
    double dayLen  = sunset - sunrise;
    if (sunrise >= sunset) {
	dayLen += 24;
    }
    if (dayTime) {
	if (now < sunrise) {
	    now += 24;
	}
	double dayFraction = (now - sunrise) / dayLen;
	return (dayFraction + 3.0/2) * M_PI;
    } else {
	double nightLen = 24 - dayLen;
	if (nightLen == 0) {
	    nightLen = 24;
	}
	if (now < sunset) {
	    now += 24;
	}
	double nightFraction = (now - sunset) / nightLen;
	return (nightFraction + 1.0/2) * M_PI;
    }
}

// angle of center of hour N on traditional Japanese wadokei clock with constant rate hand
//   12 japanese hourNumbers per day; zero for noon hour ("午")
//   results match a 24 hour watch with (local mean) noon on top
//   of questionable validity in polar latitudes
EBVM_OP1(angleForJapanHour, japanHourNumber)
{
    double sunrise = [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithSunriseForDay) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
    double sunset  = [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithSunsetForDay)  watchTimeSelector:@selector(hour24ValueUsingEnv:)];
    double dayLen  = sunrise < sunset ? sunset - sunrise : sunset+24 - sunrise;
    double nightLen= 24 - dayLen;
    if (japanHourNumber>=9) {
	// sunrise - noon
	return (sunrise + (japanHourNumber - 9) / 6 * dayLen  ) * M_PI/12 + M_PI;
    } else if (japanHourNumber >= 6) {
	// midnight - sunrise
	return (sunrise - (9 - japanHourNumber) / 6 * nightLen) * M_PI/12 + M_PI;
    } else if (japanHourNumber >= 3) {
	// sunset - midnight
	return (sunset  + (japanHourNumber - 3) / 6 * nightLen) * M_PI/12 + M_PI;
    } else {
	// noon - sunset
	return (sunset  - (3 - japanHourNumber) / 6 * dayLen  ) * M_PI/12 + M_PI;
    }
}

// 13:45:00 => 13
EBVM_OP0(hour24Number)
{
    return [[virtualMachine owner] getIntValueFromMainTime:@selector(hour24NumberUsingEnv:)];
}
EBVM_OP1(hour24NumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromTimeForEnv:timerNumber watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}
EBVM_OP0(hour24NumberAngle)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getIntValueFromMainTime:@selector(hour24NumberUsingEnv:)];
}
EBVM_OP1(hour24NumberAngleN, timerNumber)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getIntValueFromTimeForEnv:timerNumber watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}

// 13:45:00 => 13.75
EBVM_OP0(hour24Value)
{
    return [[virtualMachine owner] getValueFromMainTime:@selector(hour24ValueUsingEnv:)];
}
EBVM_OP1(hour24ValueN, timerNumber)
{
    return [[virtualMachine owner] getValueFromTimeForEnv:timerNumber watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}
EBVM_OP0(hour24ValueAngle)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getValueFromMainTime:@selector(hour24ValueUsingEnv:)];
}
EBVM_OP1(hour24ValueAngleN, timerNumber)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getValueFromTimeForEnv:timerNumber watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}

// March 1 => 0  (n.b, not 1; useful for angles and for arrays of images, and consistent with double form below)
EBVM_OP0(dayNumber)
{
    return [[virtualMachine owner] getIntValueFromMainTime:@selector(dayNumberUsingEnv:)];
}
EBVM_OP1(dayNumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromTimeForEnv:timerNumber watchTimeSelector:@selector(dayNumberUsingEnv:)];
}
// Note: dayNumber and dayValue angles are assumed to be for a dial with 31 days
EBVM_OP0(dayNumberAngle)
{
    return (2 * M_PI / 31) * [[virtualMachine owner] getIntValueFromMainTime:@selector(dayNumberUsingEnv:)];
}
EBVM_OP1(dayNumberAngleN, timerNumber)
{
    return (2 * M_PI / 31) * [[virtualMachine owner] getIntValueFromTimeForEnv:timerNumber watchTimeSelector:@selector(dayNumberUsingEnv:)];
}

// March 1 at 6pm  =>  0.75;  useful for continuous hands displaying day
EBVM_OP0(dayValue)
{
    return [[virtualMachine owner] getValueFromMainTime:@selector(dayValueUsingEnv:)];
}
EBVM_OP1(dayValueN, timerNumber)
{
    return [[virtualMachine owner] getValueFromTimeForEnv:timerNumber watchTimeSelector:@selector(dayValueUsingEnv:)];
}
// Note: dayNumber and dayValue angles are assumed to be for a dial with 31 days
EBVM_OP0(dayValueAngle)
{
    return (2 * M_PI / 31) * [[virtualMachine owner] getValueFromMainTime:@selector(dayValueUsingEnv:)];
}
EBVM_OP1(dayValueAngleN, timerNumber)
{
    return (2 * M_PI / 31) * [[virtualMachine owner] getValueFromTimeForEnv:timerNumber watchTimeSelector:@selector(dayValueUsingEnv:)];
}

// March 1 => 2  (n.b., not 3)
EBVM_OP0(monthNumber)
{
    return [[virtualMachine owner] getIntValueFromMainTime:@selector(monthNumberUsingEnv:)];
}
EBVM_OP1(monthNumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromTimeForEnv:timerNumber watchTimeSelector:@selector(monthNumberUsingEnv:)];
}
EBVM_OP0(monthNumberAngle)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getIntValueFromMainTime:@selector(monthNumberUsingEnv:)];
}
EBVM_OP1(monthNumberAngleN, timerNumber)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getIntValueFromTimeForEnv:timerNumber watchTimeSelector:@selector(monthNumberUsingEnv:)];
}

// March = 31, Nov = 30, Feb = 28 or 29 etc
EBVM_OP0(monthLen)
{
    switch ([[virtualMachine owner] getIntValueFromMainTime:@selector(monthNumberUsingEnv:)]) {
	case  0: return 31;	// Jan
    	case  1: return ([[virtualMachine owner] getBoolValueFromMainTime:@selector(leapYearUsingEnv:)] ? 29 : 28);	// Feb
    	case  2: return 31;	// Mar
    	case  3: return 30;	// Apr
    	case  4: return 31;	// May
    	case  5: return 30;	// Jun
    	case  6: return 31;	// Jul
    	case  7: return 31;	// Aug
    	case  8: return 30;	// Sep
    	case  9: return 31;	// Oct
    	case 10: return 30;	// Nov
    	case 11: return 31;	// Dec
	default: assert(false); return 31;
    }
}

// March 1 at noon  =>  12 / (31 * 24);  useful for continuous hands displaying month
EBVM_OP0(monthValue)
{
    return [[virtualMachine owner] getValueFromMainTime:@selector(monthValueUsingEnv:)];
}
EBVM_OP1(monthValueN, timerNumber)
{
    return [[virtualMachine owner] getValueFromTimeForEnv:timerNumber watchTimeSelector:@selector(monthValueUsingEnv:)];
}
EBVM_OP0(monthValueAngle)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getValueFromMainTime:@selector(monthValueUsingEnv:)];
}
EBVM_OP1(monthValueAngleN, timerNumber)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getValueFromTimeForEnv:timerNumber watchTimeSelector:@selector(monthValueUsingEnv:)];
}

// March 1 1999 => 1999
EBVM_OP0(yearNumber)
{
    return [[virtualMachine owner] getIntValueFromMainTime:@selector(yearNumberUsingEnv:)];
}
EBVM_OP1(yearNumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromTimeForEnv:timerNumber watchTimeSelector:@selector(yearNumberUsingEnv:)];
}

// March 1 1999 BCE => -1999 .  Note: NOT the astronomical number; this value will never be zero
EBVM_OP0(yearNumberCEMonotonic)
{
    ECGLWatch *theWatch = [virtualMachine owner];
    int yearNumber = [theWatch getIntValueFromMainTime:@selector(yearNumberUsingEnv:)];
    int eraNumber = [theWatch getIntValueFromMainTime:@selector(eraNumberUsingEnv:)];
    return eraNumber ? yearNumber : -yearNumber;
}
EBVM_OP1(yearNumberCEMonotonicN, timerNumber)
{
    ECGLWatch *theWatch = [virtualMachine owner];
    int yearNumber = [theWatch getIntValueFromTimeForEnv:timerNumber watchTimeSelector:@selector(yearNumberUsingEnv:)];
    int eraNumber = [theWatch getIntValueFromTimeForEnv:timerNumber watchTimeSelector:@selector(eraNumberUsingEnv:)];
    return eraNumber ? yearNumber : -yearNumber;
}

// March 1 1999 BCE => -1998   This value does return 0 in 1BCE
EBVM_OP0(yearNumberAstroMonotonic)
{
    ECGLWatch *theWatch = [virtualMachine owner];
    int yearNumber = [theWatch getIntValueFromMainTime:@selector(yearNumberUsingEnv:)];
    int eraNumber = [theWatch getIntValueFromMainTime:@selector(eraNumberUsingEnv:)];
    return eraNumber ? yearNumber : 1 - yearNumber;
}
EBVM_OP1(yearNumberAstroMonotonicN, timerNumber)
{
    ECGLWatch *theWatch = [virtualMachine owner];
    int yearNumber = [theWatch getIntValueFromTimeForEnv:timerNumber watchTimeSelector:@selector(yearNumberUsingEnv:)];
    int eraNumber = [theWatch getIntValueFromTimeForEnv:timerNumber watchTimeSelector:@selector(eraNumberUsingEnv:)];
    return eraNumber ? yearNumber : 1 - yearNumber;
}

// BCE => 0; CE => 1
EBVM_OP0(eraNumber)
{
    return [[virtualMachine owner] getIntValueFromMainTime:@selector(eraNumberUsingEnv:)];
}
EBVM_OP1(eraNumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromTimeForEnv:timerNumber watchTimeSelector:@selector(eraNumberUsingEnv:)];
}

// daylight => 1; standard => 0
EBVM_OP0(DSTNumber)
{
    return (double)[[virtualMachine owner] getBoolValueFromMainTime:@selector(isDSTUsingEnv:)];
}

EBVM_OP0(DSTNumberAngle)
{
    return M_PI * [[virtualMachine owner] getBoolValueFromMainTime:@selector(isDSTUsingEnv:)];
}

// Sunday => 0
EBVM_OP0(weekdayNumber)
{
    return [[virtualMachine owner] getIntValueFromMainTime:@selector(weekdayNumberUsingEnv:)];
}
EBVM_OP1(weekdayNumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromTimeForEnv:timerNumber watchTimeSelector:@selector(weekdayNumberUsingEnv:)];
}
EBVM_OP0(weekdayNumberAngle)
{
    return (2 * M_PI / 7) * [[virtualMachine owner] getIntValueFromMainTime:@selector(weekdayNumberUsingEnv:)];
}
EBVM_OP1(weekdayNumberAngleN, timerNumber)
{
    return (2 * M_PI / 7) * [[virtualMachine owner] getIntValueFromTimeForEnv:timerNumber watchTimeSelector:@selector(weekdayNumberUsingEnv:)];
}

// Tuesday at 6pm => 2.75
EBVM_OP0(weekdayValue)
{
    return [[virtualMachine owner] getValueFromMainTime:@selector(weekdayValueUsingEnv:)];
}
EBVM_OP1(weekdayValueN, timerNumber)
{
    return [[virtualMachine owner] getValueFromTimeForEnv:timerNumber watchTimeSelector:@selector(weekdayValueUsingEnv:)];
}
EBVM_OP0(weekdayValueAngle)
{
    return (2 * M_PI / 7) * [[virtualMachine owner] getValueFromMainTime:@selector(weekdayValueUsingEnv:)];
}
EBVM_OP1(weekdayValueAngleN, timerNumber)
{
    return (2 * M_PI / 7) * [[virtualMachine owner] getValueFromTimeForEnv:timerNumber watchTimeSelector:@selector(weekdayValueUsingEnv:)];
}

EBVM_OP0(dayOfYearNumber)
{
    return [[virtualMachine owner] getValueFromMainTime:@selector(dayOfYearNumberUsingEnv:)];
}

EBVM_OP1(dayOfYearNumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromTimeForEnv:timerNumber watchTimeSelector:@selector(dayOfYearNumberUsingEnv:)];
}

EBVM_OP0(weekOfYearNumber)
{
    return [[virtualMachine owner] mainTimeWeekOfYearNumber];
}

EBVM_OP1(weekOfYearNumberN, timerNumber)
{
    return [[virtualMachine owner] weekOfYearNumberForEnv:timerNumber];
}

EBVM_OP1(rotationForCalendarWheel012B, wheelWeekdayStart)
{
    return [[virtualMachine owner] rotationForCalendarWheel012BDesignedForWeekdayStart:wheelWeekdayStart];
}

EBVM_OP1(rotationForCalendarWheel3456, wheelWeekdayStart)
{
    return [[virtualMachine owner] rotationForCalendarWheel3456DesignedForWeekdayStart:wheelWeekdayStart];
}

EBVM_OP1(rotationForCalendarWheelOct1582, wheelWeekdayStart)
{
    return [[virtualMachine owner] rotationForCalendarWheelOct1582DesignedForWeekdayStart:wheelWeekdayStart];
}

EBVM_OP0(calendarColumn)
{
    return [[virtualMachine owner] calendarColumn];
}

EBVM_OP0(calendarRow)
{
    // return [[virtualMachine owner] getIntValueFromMainTime:@selector(secondNumberUsingEnv:)] % 6;
    return [[virtualMachine owner] calendarRow];
}

EBVM_OP4(calendarRowCoverOffsetForType, coverType, overallWidth, cellWidth, spacingWidth)
{
    return [[virtualMachine owner] calendarRowCoverOffsetForType:(ECCalendarRowCoverType)rint(coverType)
                                                    overallWidth:overallWidth
                                                       cellWidth:cellWidth
                                                    spacingWidth:spacingWidth];
}

EBVM_OP4(calendarRowUnderlayOffsetForType, coverType, overallWidth, cellWidth, spacingWidth)
{
    return [[virtualMachine owner] calendarRowUnderlayOffsetForType:(ECCalendarRowCoverType)rint(coverType)
                                                       overallWidth:overallWidth
                                                          cellWidth:cellWidth
                                                       spacingWidth:spacingWidth];
}

EBVM_OP0(calendarWeekdayStart)
{
    return ECCalendarWeekdayStart;
}

EBVM_OP0(lstValue)
{
    return [[[virtualMachine owner] mainAstro] localSiderealTime];
}

EBVM_OP0(eclipseSeparation)
{
    return [[[virtualMachine owner] mainAstro] eclipseSeparation];
}

EBVM_OP0(eclipseKind)
{
    int value = (int)rint([[[virtualMachine owner] mainAstro] eclipseKind]);
    if (value > 0) value--;  // Wheel assumes only one "none" value, but we are now returning ECEclipseNoneSolar and ECEclipseNoneLunar as separate values 0, 1
    return value;
}

// This is here because of Android, which uses a different eclipse kind enum with an extra value.  *This* op, however, only runs on iOS and so should
// return the same value as eclipseKind.
EBVM_OP0(legacyEclipseKind)
{
    int value = (int)rint([[[virtualMachine owner] mainAstro] eclipseKind]);
    if (value > 0) value--;  // Wheel assumes only one "none" value, but we are now returning ECEclipseNoneSolar and ECEclipseNoneLunar as separate values 0, 1
    return value;
}

EBVM_OP0(moonElongation)
{
    ECAstronomyManager *astro = [[virtualMachine owner] mainAstro];
    double eclipseAngularSeparation = [astro eclipseAngularSeparation];
    ECEclipseKind eclipseKind = [astro eclipseKind];
    if ([ECAstronomyManager eclipseKindIsMoreSolarThanLunar:eclipseKind]) {
        return eclipseAngularSeparation;
    } else {
        return M_PI - eclipseAngularSeparation;
    }
}

// STOPWATCH METHODS

// Start/Stop
// Rounding value is precision of mechanical stopwatch movement; values are rounded to this number when stopped
EBVM_OP1(stopwatchStartStop, rounding)
{
    ECGLWatch *owner = [virtualMachine owner];
    [owner stopwatchStartStopWithRounding:rounding];
    return 0;
}

// Set value to 0
EBVM_OP0(stopwatchReset)
{
    ECGLWatch *owner = [virtualMachine owner];
    [owner stopwatchReset];
    return 0;
}

EBVM_OP1(stopwatchRattrapante, rounding)
{
    ECGLWatch *owner = [virtualMachine owner];
    [owner stopwatchRattrapanteWithRounding:rounding];
    return 0;
}

EBVM_OP0(stopwatchRattrapanteValid)
{
    ECGLWatch *owner = [virtualMachine owner];
    ECWatchTime *stopwatchTime = [owner stopwatchTimer];
    ECWatchTime *stopwatchLapTime = [owner stopwatchLapTimer];
    return [stopwatchLapTime isStopped] && [stopwatchTime isIdenticalTo:stopwatchLapTime] ? 0 : 1;
}

// Copy lap time
EBVM_OP0(copyLapTime)
{
    [[[virtualMachine owner] stopwatchLapTimer]
	copyLapTimeFromOtherTimer:[[virtualMachine owner] stopwatchTimer]];
    return 0;
}

// This is a little counterintuitive.  There are two watch times involved here:
// 1) the "dial" stopwatch display, which is what the hands are displaying
// 2) the "main" stopwatch time, which is what we're measuring with the top button.
// The "lap" time is not on a watchTime at all in this model.  Lap times in this model appear
// temporarily on the "dial" watchTime but then disappear when the "dial" watch starts
// up again.
// There is another model for lap times, in which a separate display is used for the lap time,
// or even multiple lap times.  In that model obviously the lap time would get its own watchTime.
// NOTE: THIS PROBABLY DOESN'T WORK WITH SKEW
static void doLapReset(ECWatchTime *stopwatchDisplayTime,
		       ECWatchTime *stopwatchTime)
{
    if ([stopwatchTime isStopped]) {
	if ([stopwatchTime isIdenticalTo:stopwatchDisplayTime]) {
	    [stopwatchTime stopwatchReset];
	    [stopwatchDisplayTime stopwatchReset];
	} else {
	    // must be displaying lap time.  Go back to actual time
	    [stopwatchDisplayTime makeTimeIdenticalToOtherTimer:stopwatchTime];
	}
    } else {  // stopwatch still running
	if ([stopwatchDisplayTime isStopped]) {
	    [stopwatchDisplayTime makeTimeIdenticalToOtherTimer:stopwatchTime];
	} else {
	    [stopwatchDisplayTime copyLapTimeFromOtherTimer:stopwatchTime];  // Could just stop, but this seems safer
	}
    }
}

// Traditional lap/reset button
EBVM_OP0(stopwatchLapReset)
{
    doLapReset([[virtualMachine owner] stopwatchDisplayTimer],
	       [[virtualMachine owner] stopwatchTimer]);
    return 0;
}

// 00:04:03.9 => 3
EBVM_OP0(stopwatchSecondNumber)
{
    return [[[virtualMachine owner] stopwatchTimer] stopwatchSecondNumber];
}
EBVM_OP0(stopwatchLapSecondNumber)
{
    return [[[virtualMachine owner] stopwatchLapTimer] stopwatchSecondNumber];
}
EBVM_OP0(stopwatchDisplaySecondNumber)
{
    return [[[virtualMachine owner] stopwatchDisplayTimer] stopwatchSecondNumber];
}
EBVM_OP0(stopwatchSecondNumberAngle)
{
    return (2 * M_PI / 60) * [[[virtualMachine owner] stopwatchTimer] stopwatchSecondNumber];
}
EBVM_OP0(stopwatchLapSecondNumberAngle)
{
    return (2 * M_PI / 60) * [[[virtualMachine owner] stopwatchLapTimer] stopwatchSecondNumber];
}
EBVM_OP0(stopwatchDisplaySecondNumberAngle)
{
    return (2 * M_PI / 60) * [[[virtualMachine owner] stopwatchDisplayTimer] stopwatchSecondNumber];
}

// 00:04:03.9 => 3.9
EBVM_OP0(stopwatchSecondValue)
{
    return [[[virtualMachine owner] stopwatchTimer] stopwatchSecondValue];
}
EBVM_OP0(stopwatchLapSecondValue)
{
    return [[[virtualMachine owner] stopwatchLapTimer] stopwatchSecondValue];
}
EBVM_OP0(stopwatchDisplaySecondValue)
{
    return [[[virtualMachine owner] stopwatchDisplayTimer] stopwatchSecondValue];
}
EBVM_OP0(stopwatchSecondValueAngle)
{
    return (2 * M_PI / 60) * [[[virtualMachine owner] stopwatchTimer] stopwatchSecondValue];
}
EBVM_OP0(stopwatchLapSecondValueAngle)
{
    return (2 * M_PI / 60) * [[[virtualMachine owner] stopwatchLapTimer] stopwatchSecondValue];
}
EBVM_OP0(stopwatchDisplaySecondValueAngle)
{
    return (2 * M_PI / 60) * [[[virtualMachine owner] stopwatchDisplayTimer] stopwatchSecondValue];
}

// 01:04:45 => 4
EBVM_OP0(stopwatchMinuteNumber)
{
    return [[[virtualMachine owner] stopwatchTimer] stopwatchMinuteNumber];
}
EBVM_OP0(stopwatchLapMinuteNumber)
{
    return [[[virtualMachine owner] stopwatchLapTimer] stopwatchMinuteNumber];
}
EBVM_OP0(stopwatchDisplayMinuteNumber)
{
    return [[[virtualMachine owner] stopwatchDisplayTimer] stopwatchMinuteNumber];
}
EBVM_OP0(stopwatchMinuteNumberAngle)
{
    return (2 * M_PI / 60) * [[[virtualMachine owner] stopwatchTimer] stopwatchMinuteNumber];
}
EBVM_OP0(stopwatchLapMinuteNumberAngle)
{
    return (2 * M_PI / 60) * [[[virtualMachine owner] stopwatchLapTimer] stopwatchMinuteNumber];
}
EBVM_OP0(stopwatchDisplayMinuteNumberAngle)
{
    return (2 * M_PI / 60) * [[[virtualMachine owner] stopwatchDisplayTimer] stopwatchMinuteNumber];
}

// 01:04:45 => 4.75
EBVM_OP0(stopwatchMinuteValue)
{
    return [[[virtualMachine owner] stopwatchTimer] stopwatchMinuteValue];
}
EBVM_OP0(stopwatchLapMinuteValue)
{
    return [[[virtualMachine owner] stopwatchLapTimer] stopwatchMinuteValue];
}
EBVM_OP0(stopwatchDisplayMinuteValue)
{
    return [[[virtualMachine owner] stopwatchDisplayTimer] stopwatchMinuteValue];
}
EBVM_OP0(stopwatchMinuteValueAngle)
{
    return (2 * M_PI / 60) * [[[virtualMachine owner] stopwatchTimer] stopwatchMinuteValue];
}
EBVM_OP0(stopwatchLapMinuteValueAngle)
{
    return (2 * M_PI / 60) * [[[virtualMachine owner] stopwatchLapTimer] stopwatchMinuteValue];
}
EBVM_OP0(stopwatchDisplayMinuteValueAngle)
{
    return (2 * M_PI / 60) * [[[virtualMachine owner] stopwatchDisplayTimer] stopwatchMinuteValue];
}

// 5d 01:30:00 => 1.5
EBVM_OP0(stopwatchHour24Value)
{
    return [[[virtualMachine owner] stopwatchTimer] stopwatchHour24Value];
}
EBVM_OP0(stopwatchLapHour24Value)
{
    return [[[virtualMachine owner] stopwatchLapTimer] stopwatchHour24Value];
}
EBVM_OP0(stopwatchDisplayHour24Value)
{
    return [[[virtualMachine owner] stopwatchDisplayTimer] stopwatchHour24Value];
}
EBVM_OP0(stopwatchHour24ValueAngle)
{
    return (2 * M_PI / 24) * [[[virtualMachine owner] stopwatchTimer] stopwatchHour24Value];
}
EBVM_OP0(stopwatchLapHour24ValueAngle)
{
    return (2 * M_PI / 24) * [[[virtualMachine owner] stopwatchLapTimer] stopwatchHour24Value];
}
EBVM_OP0(stopwatchDisplayHour24ValueAngle)
{
    return (2 * M_PI / 24) * [[[virtualMachine owner] stopwatchDisplayTimer] stopwatchHour24Value];
}

// 5d 01:30:00 => 1.5
EBVM_OP0(stopwatchHour12Value)
{
    return [[[virtualMachine owner] stopwatchTimer] stopwatchHour12Value];
}
EBVM_OP0(stopwatchLapHour12Value)
{
    return [[[virtualMachine owner] stopwatchLapTimer] stopwatchHour12Value];
}
EBVM_OP0(stopwatchDisplayHour12Value)
{
    return [[[virtualMachine owner] stopwatchDisplayTimer] stopwatchHour12Value];
}
EBVM_OP0(stopwatchHour12ValueAngle)
{
    return (2 * M_PI / 12) * [[[virtualMachine owner] stopwatchTimer] stopwatchHour12Value];
}
EBVM_OP0(stopwatchLapHour12ValueAngle)
{
    return (2 * M_PI / 12) * [[[virtualMachine owner] stopwatchLapTimer] stopwatchHour12Value];
}
EBVM_OP0(stopwatchDisplayHour12ValueAngle)
{
    return (2 * M_PI / 12) * [[[virtualMachine owner] stopwatchDisplayTimer] stopwatchHour12Value];
}

// 5d 18:00:00 => 5
EBVM_OP0(stopwatchDayNumber)
{
    return [[[virtualMachine owner] stopwatchTimer] stopwatchDayNumber];
}
EBVM_OP0(stopwatchLapDayNumber)
{
    return [[[virtualMachine owner] stopwatchLapTimer] stopwatchDayNumber];
}
EBVM_OP0(stopwatchDisplayDayNumber)
{
    return [[[virtualMachine owner] stopwatchDisplayTimer] stopwatchDayNumber];
}
// No Angle ops: No standard number of days on the dial

// 5d 18:00:00 => 5.75
EBVM_OP0(stopwatchDayValue)
{
    return [[[virtualMachine owner] stopwatchTimer] stopwatchDayValue];
}
EBVM_OP0(stopwatchLapDayValue)
{
    return [[[virtualMachine owner] stopwatchLapTimer] stopwatchDayValue];
}
EBVM_OP0(stopwatchDisplayDayValue)
{
    return [[[virtualMachine owner] stopwatchDisplayTimer] stopwatchDayValue];
}
// No stopwatch angle ops: No standard number of days on the dial

// Alarm ops

// 12:35:45.9 => 45
EBVM_OP0(alarmSecondNumber)
{
    return [[virtualMachine owner] getIntValueFromAlarmTime:@selector(secondNumberUsingEnv:)];
}
EBVM_OP0(alarmSecondNumberAngle)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getIntValueFromAlarmTime:@selector(secondNumberUsingEnv:)];
}

// 12:35:45.9 => 45.9
EBVM_OP0(alarmSecondValue)
{
    return [[virtualMachine owner] getValueFromAlarmTime:@selector(secondValueUsingEnv:)];
}
EBVM_OP0(alarmSecondValueAngle)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getValueFromAlarmTime:@selector(secondValueUsingEnv:)];
}

// 12:35:45 => 35
EBVM_OP0(alarmMinuteNumber)
{
    return [[virtualMachine owner] getIntValueFromAlarmTime:@selector(minuteNumberUsingEnv:)];
}
EBVM_OP0(alarmMinuteNumberAngle)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getIntValueFromAlarmTime:@selector(minuteNumberUsingEnv:)];
}

// 12:35:45 => 35.75
EBVM_OP0(alarmMinuteValue)
{
    return [[virtualMachine owner] getValueFromAlarmTime:@selector(minuteValueUsingEnv:)];
}
EBVM_OP0(alarmMinuteValueAngle)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getValueFromAlarmTime:@selector(minuteValueUsingEnv:)];
}

// 13:45:00 => 1
EBVM_OP0(alarmHour12Number)
{
    return [[virtualMachine owner] getIntValueFromAlarmTime:@selector(hour12NumberUsingEnv:)];
}
EBVM_OP0(alarmHour12NumberAngle)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getIntValueFromAlarmTime:@selector(hour12NumberUsingEnv:)];
}

// 13:45:00 => 1.75
EBVM_OP0(alarmHour12Value)
{
    return [[virtualMachine owner] getValueFromAlarmTime:@selector(hour12ValueUsingEnv:)];
}
EBVM_OP0(alarmHour12ValueAngle)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getValueFromAlarmTime:@selector(hour12ValueUsingEnv:)];
}

// 13:45:00 => 13
EBVM_OP0(alarmHour24Number)
{
    return [[virtualMachine owner] getIntValueFromAlarmTime:@selector(hour24NumberUsingEnv:)];
}
EBVM_OP0(alarmHour24NumberAngle)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getIntValueFromAlarmTime:@selector(hour24NumberUsingEnv:)];
}

// 13:45:00 => 13.75
EBVM_OP0(alarmHour24Value)
{
    return [[virtualMachine owner] getValueFromAlarmTime:@selector(hour24ValueUsingEnv:)];
}
EBVM_OP0(alarmHour24ValueAngle)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getValueFromAlarmTime:@selector(hour24ValueUsingEnv:)];
}

// Interval ops

// 12:35:45.9 => 45
EBVM_OP0(intervalSecondNumber)
{
    return [[[virtualMachine owner] intervalTimer] stopwatchSecondNumber];
}
// All angles are in radians cw from 12, based on a logical dial displaying the unit
EBVM_OP0(intervalSecondNumberAngle)
{
    return (2 * M_PI / 60) * [[[virtualMachine owner] intervalTimer] stopwatchSecondNumber];
}

// 12:35:45.9 => 45.9
EBVM_OP0(intervalSecondValue)
{
    return [[[virtualMachine owner] intervalTimer] stopwatchSecondValue];
}
EBVM_OP0(intervalSecondValueAngle)
{
    return (2 * M_PI / 60) * [[[virtualMachine owner] intervalTimer] stopwatchSecondValue];
}

// 12:35:45 => 35
EBVM_OP0(intervalMinuteNumber)
{
    return [[[virtualMachine owner] intervalTimer] stopwatchMinuteNumber];
}
EBVM_OP0(intervalMinuteNumberAngle)
{
    return (2 * M_PI / 60) * [[[virtualMachine owner] intervalTimer] stopwatchMinuteNumber];
}

// 12:35:45 => 35.75
EBVM_OP0(intervalMinuteValue)
{
    return [[[virtualMachine owner] intervalTimer] stopwatchMinuteValue];
}
EBVM_OP0(intervalMinuteValueAngle)
{
    return (2 * M_PI / 60) * [[[virtualMachine owner] intervalTimer] stopwatchMinuteValue];
}

// 13:45:00 => 1
EBVM_OP0(intervalHour12Number)
{
    return [[[virtualMachine owner] intervalTimer] stopwatchHour12Number];
}
EBVM_OP0(intervalHour12NumberAngle)
{
    return (2 * M_PI / 12) * [[[virtualMachine owner] intervalTimer] stopwatchHour12Number];
}

// 13:45:00 => 1.75
EBVM_OP0(intervalHour12Value)
{
    return [[[virtualMachine owner] intervalTimer] stopwatchHour12Value];
}
EBVM_OP0(intervalHour12ValueAngle)
{
    return (2 * M_PI / 12) * [[[virtualMachine owner] intervalTimer] stopwatchHour12Value];
}

// 13:45:00 => 13
EBVM_OP0(intervalHour24Number)
{
    return [[[virtualMachine owner] intervalTimer] stopwatchHour24Number];
}
EBVM_OP0(intervalHour24NumberAngle)
{
    return (2 * M_PI / 24) * [[[virtualMachine owner] intervalTimer] stopwatchHour24Number];
}

// 13:45:00 => 13.75
EBVM_OP0(intervalHour24Value)
{
    return [[[virtualMachine owner] intervalTimer] stopwatchHour24Value];
}
EBVM_OP0(intervalHour24ValueAngle)
{
    return (2 * M_PI / 24) * [[[virtualMachine owner] intervalTimer] stopwatchHour24Value];
}

// Astro ops

// 12:35:45 => 35
EBVM_OP0(sunriseForDayMinuteNumber)
{
    return [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithSunriseForDay) watchTimeSelector:@selector(minuteNumberUsingEnv:)];
    //return [[[[virtualMachine owner] mainAstro] watchTimeWithSunriseForDay] minuteNumber];
}
EBVM_OP1(sunriseForDayMinuteNumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithSunriseForDay) watchTimeSelector:@selector(minuteNumberUsingEnv:)];
    //return [[[[virtualMachine owner] astroWithIndex:timerNumber] watchTimeWithSunriseForDay] minuteNumber];
}
EBVM_OP0(sunriseForDayMinuteNumberAngle)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithSunriseForDay) watchTimeSelector:@selector(minuteNumberUsingEnv:)];
}
EBVM_OP1(sunriseForDayMinuteNumberAngleN, timerNumber)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithSunriseForDay) watchTimeSelector:@selector(minuteNumberUsingEnv:)];
}

// 12:35:45 => 35.75
EBVM_OP0(sunriseForDayMinuteValue)
{
    return [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithSunriseForDay) watchTimeSelector:@selector(minuteValueUsingEnv:)];
}
EBVM_OP1(sunriseForDayMinuteValueN, timerNumber)
{
    return [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithSunriseForDay) watchTimeSelector:@selector(minuteValueUsingEnv:)];
}
EBVM_OP0(sunriseForDayMinuteValueAngle)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithSunriseForDay) watchTimeSelector:@selector(minuteValueUsingEnv:)];
}
EBVM_OP1(sunriseForDayMinuteValueAngleN, timerNumber)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithSunriseForDay) watchTimeSelector:@selector(minuteValueUsingEnv:)];
}

// 13:45:00 => 1
EBVM_OP0(sunriseForDayHour12Number)
{
    return [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithSunriseForDay) watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}
EBVM_OP1(sunriseForDayHour12NumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithSunriseForDay) watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}
EBVM_OP0(sunriseForDayHour12NumberAngle)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithSunriseForDay) watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}
EBVM_OP1(sunriseForDayHour12NumberAngleN, timerNumber)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithSunriseForDay) watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}

// 13:45:00 => 1.75
EBVM_OP0(sunriseForDayHour12Value)
{
    return [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithSunriseForDay) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}
EBVM_OP1(sunriseForDayHour12ValueN, timerNumber)
{
    return [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithSunriseForDay) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}
EBVM_OP0(sunriseForDayHour12ValueAngle)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithSunriseForDay) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}
EBVM_OP1(sunriseForDayHour12ValueAngleN, timerNumber)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithSunriseForDay) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}

// 13:45:00 => 13
EBVM_OP0(sunriseForDayHour24Number)
{
    return [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithSunriseForDay) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}
EBVM_OP1(sunriseForDayHour24NumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithSunriseForDay) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}
EBVM_OP0(sunriseForDayHour24NumberAngle)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithSunriseForDay) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}
EBVM_OP1(sunriseForDayHour24NumberAngleN, timerNumber)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithSunriseForDay) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}

// 13:45:00 => 13.75
EBVM_OP0(sunriseForDayHour24Value)
{
    return [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithSunriseForDay) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}
EBVM_OP1(sunriseForDayHour24ValueN, timerNumber)
{
    return [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithSunriseForDay) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}
EBVM_OP0(sunriseForDayHour24ValueAngle)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithSunriseForDay) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}
EBVM_OP1(sunriseForDayHour24ValueAngleN, timerNumber)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithSunriseForDay) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}

EBVM_OP0(sunriseForDayValid)
{
    return [[[virtualMachine owner] mainAstro] sunriseForDayValid];
}
EBVM_OP1(sunriseForDayValidN, timerNumber)
{
    return [[[virtualMachine owner] astroWithIndex:timerNumber] sunriseForDayValid];
}

// 12:35:45 => 35
EBVM_OP0(sunsetForDayMinuteNumber)
{
    return [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithSunsetForDay) watchTimeSelector:@selector(minuteNumberUsingEnv:)];
}
EBVM_OP1(sunsetForDayMinuteNumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithSunsetForDay) watchTimeSelector:@selector(minuteNumberUsingEnv:)];
}
EBVM_OP0(sunsetForDayMinuteNumberAngle)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithSunsetForDay) watchTimeSelector:@selector(minuteNumberUsingEnv:)];
}
EBVM_OP1(sunsetForDayMinuteNumberAngleN, timerNumber)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithSunsetForDay) watchTimeSelector:@selector(minuteNumberUsingEnv:)];
}

// 12:35:45 => 35.75
EBVM_OP0(sunsetForDayMinuteValue)
{
    return [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithSunsetForDay) watchTimeSelector:@selector(minuteValueUsingEnv:)];
}
EBVM_OP1(sunsetForDayMinuteValueN, timerNumber)
{
    return [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithSunsetForDay) watchTimeSelector:@selector(minuteValueUsingEnv:)];
}
EBVM_OP0(sunsetForDayMinuteValueAngle)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithSunsetForDay) watchTimeSelector:@selector(minuteValueUsingEnv:)];
}
EBVM_OP1(sunsetForDayMinuteValueAngleN, timerNumber)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithSunsetForDay) watchTimeSelector:@selector(minuteValueUsingEnv:)];
}

// 13:45:00 => 1
EBVM_OP0(sunsetForDayHour12Number)
{
    return [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithSunsetForDay) watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}
EBVM_OP1(sunsetForDayHour12NumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithSunsetForDay) watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}
EBVM_OP0(sunsetForDayHour12NumberAngle)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithSunsetForDay) watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}
EBVM_OP1(sunsetForDayHour12NumberAngleN, timerNumber)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithSunsetForDay) watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}

// 13:45:00 => 1.75
EBVM_OP0(sunsetForDayHour12Value)
{
    return [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithSunsetForDay) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}
EBVM_OP1(sunsetForDayHour12ValueN, timerNumber)
{
    return [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithSunsetForDay) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}
EBVM_OP0(sunsetForDayHour12ValueAngle)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithSunsetForDay) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}
EBVM_OP1(sunsetForDayHour12ValueAngleN, timerNumber)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithSunsetForDay) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}

// 13:45:00 => 13
EBVM_OP0(sunsetForDayHour24Number)
{
    return [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithSunsetForDay) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}
EBVM_OP1(sunsetForDayHour24NumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithSunsetForDay) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}
EBVM_OP0(sunsetForDayHour24NumberAngle)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithSunsetForDay) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}
EBVM_OP1(sunsetForDayHour24NumberAngleN, timerNumber)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithSunsetForDay) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}

// 13:45:00 => 13.75
EBVM_OP0(sunsetForDayHour24Value)
{
    return [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithSunsetForDay) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}
EBVM_OP1(sunsetForDayHour24ValueN, timerNumber)
{
    return [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithSunsetForDay) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}
EBVM_OP0(sunsetForDayHour24ValueAngle)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithSunsetForDay) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}
EBVM_OP1(sunsetForDayHour24ValueAngleN, timerNumber)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithSunsetForDay) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}

EBVM_OP0(sunsetForDayValid)
{
    return [[[virtualMachine owner] mainAstro] sunsetForDayValid];
}
EBVM_OP1(sunsetForDayValidN, timerNumber)
{
    return [[[virtualMachine owner] astroWithIndex:timerNumber] sunsetForDayValid];
}

// hook

// 12:35:45 => 35
EBVM_OP0(nextSunriseMinuteNumber)
{
    return [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithNextSunrise) watchTimeSelector:@selector(minuteNumberUsingEnv:)];
}
EBVM_OP1(nextSunriseMinuteNumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextSunrise) watchTimeSelector:@selector(minuteNumberUsingEnv:)];
}
EBVM_OP0(nextSunriseMinuteNumberAngle)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithNextSunrise) watchTimeSelector:@selector(minuteNumberUsingEnv:)];
}
EBVM_OP1(nextSunriseMinuteNumberAngleN, timerNumber)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextSunrise) watchTimeSelector:@selector(minuteNumberUsingEnv:)];
}

// 12:35:45 => 35.75
EBVM_OP0(nextSunriseMinuteValue)
{
    return [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithNextSunrise) watchTimeSelector:@selector(minuteValueUsingEnv:)];
}
EBVM_OP1(nextSunriseMinuteValueN, timerNumber)
{
    return [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextSunrise) watchTimeSelector:@selector(minuteValueUsingEnv:)];
}
EBVM_OP0(nextSunriseMinuteValueAngle)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithNextSunrise) watchTimeSelector:@selector(minuteValueUsingEnv:)];
}
EBVM_OP1(nextSunriseMinuteValueAngleN, timerNumber)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextSunrise) watchTimeSelector:@selector(minuteValueUsingEnv:)];
}

// 13:45:00 => 1
EBVM_OP0(nextSunriseHour12Number)
{
    return [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithNextSunrise) watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}
EBVM_OP1(nextSunriseHour12NumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextSunrise) watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}
EBVM_OP0(nextSunriseHour12NumberAngle)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithNextSunrise) watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}
EBVM_OP1(nextSunriseHour12NumberAngleN, timerNumber)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextSunrise) watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}

// 13:45:00 => 1.75
EBVM_OP0(nextSunriseHour12Value)
{
    return [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithNextSunrise) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}
EBVM_OP1(nextSunriseHour12ValueN, timerNumber)
{
    return [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextSunrise) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}
EBVM_OP0(nextSunriseHour12ValueAngle)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithNextSunrise) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}
EBVM_OP1(nextSunriseHour12ValueAngleN, timerNumber)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextSunrise) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}

// 13:45:00 => 13
EBVM_OP0(nextSunriseHour24Number)
{
    return [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithNextSunrise) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}
EBVM_OP1(nextSunriseHour24NumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextSunrise) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}
EBVM_OP0(nextSunriseHour24NumberAngle)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithNextSunrise) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}
EBVM_OP1(nextSunriseHour24NumberAngleN, timerNumber)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextSunrise) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}

// 13:45:00 => 13.75
EBVM_OP0(nextSunriseHour24Value)
{
    return [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithNextSunrise) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}
EBVM_OP1(nextSunriseHour24ValueN, timerNumber)
{
    return [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextSunrise) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}
EBVM_OP0(nextSunriseHour24ValueAngle)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithNextSunrise) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}
EBVM_OP1(nextSunriseHour24ValueAngleN, timerNumber)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextSunrise) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}
EBVM_OP0(nextSunriseDayOffset)
{
    return [[virtualMachine owner] getDayOffsetValueFromMainAstroWatchTime:@selector(watchTimeWithNextSunrise)];
}
EBVM_OP1(nextSunriseDayOffsetN, timerNumber)
{
    return [[virtualMachine owner] getDayOffsetValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextSunrise)];
}
EBVM_OP0(nextSunriseValid)
{
    return [[[virtualMachine owner] mainAstro] nextSunriseValid];
}
EBVM_OP1(nextSunriseValidN, timerNumber)
{
    return [[[virtualMachine owner] astroWithIndex:timerNumber] nextSunriseValid];
}

EBVM_OP1(nextPlanetriseValid, planetNumber)
{
    return [[[virtualMachine owner] mainAstro] nextPlanetriseValid:planetNumber];
}
EBVM_OP1(nextPlanetsetValid, planetNumber)
{
    return [[[virtualMachine owner] mainAstro] nextPlanetsetValid:planetNumber];
}


// 12:35:45 => 35
EBVM_OP0(nextSunsetMinuteNumber)
{
    return [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithNextSunset) watchTimeSelector:@selector(minuteNumberUsingEnv:)];
}
EBVM_OP1(nextSunsetMinuteNumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextSunset) watchTimeSelector:@selector(minuteNumberUsingEnv:)];
}
EBVM_OP0(nextSunsetMinuteNumberAngle)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithNextSunset) watchTimeSelector:@selector(minuteNumberUsingEnv:)];
}
EBVM_OP1(nextSunsetMinuteNumberAngleN, timerNumber)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextSunset) watchTimeSelector:@selector(minuteNumberUsingEnv:)];
}

// 12:35:45 => 35.75
EBVM_OP0(nextSunsetMinuteValue)
{
    return [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithNextSunset) watchTimeSelector:@selector(minuteValueUsingEnv:)];
}
EBVM_OP1(nextSunsetMinuteValueN, timerNumber)
{
    return [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextSunset) watchTimeSelector:@selector(minuteValueUsingEnv:)];
}
EBVM_OP0(nextSunsetMinuteValueAngle)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithNextSunset) watchTimeSelector:@selector(minuteValueUsingEnv:)];
}
EBVM_OP1(nextSunsetMinuteValueAngleN, timerNumber)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextSunset) watchTimeSelector:@selector(minuteValueUsingEnv:)];
}

// 13:45:00 => 1
EBVM_OP0(nextSunsetHour12Number)
{
    return [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithNextSunset) watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}
EBVM_OP1(nextSunsetHour12NumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextSunset) watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}
EBVM_OP0(nextSunsetHour12NumberAngle)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithNextSunset) watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}
EBVM_OP1(nextSunsetHour12NumberAngleN, timerNumber)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextSunset) watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}

// 13:45:00 => 1.75
EBVM_OP0(nextSunsetHour12Value)
{
    return [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithNextSunset) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}
EBVM_OP1(nextSunsetHour12ValueN, timerNumber)
{
    return [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextSunset) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}
EBVM_OP0(nextSunsetHour12ValueAngle)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithNextSunset) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}
EBVM_OP1(nextSunsetHour12ValueAngleN, timerNumber)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextSunset) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}

// 13:45:00 => 13
EBVM_OP0(nextSunsetHour24Number)
{
    return [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithNextSunset) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}
EBVM_OP1(nextSunsetHour24NumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextSunset) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}
EBVM_OP0(nextSunsetHour24NumberAngle)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithNextSunset) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}
EBVM_OP1(nextSunsetHour24NumberAngleN, timerNumber)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextSunset) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}

// 13:45:00 => 13.75
EBVM_OP0(nextSunsetHour24Value)
{
    return [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithNextSunset) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}
EBVM_OP1(nextSunsetHour24ValueN, timerNumber)
{
    return [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextSunset) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}
EBVM_OP0(nextSunsetHour24ValueAngle)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithNextSunset) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}
EBVM_OP1(nextSunsetHour24ValueAngleN, timerNumber)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextSunset) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}
EBVM_OP0(nextSunsetDayOffset)
{
    return [[virtualMachine owner] getDayOffsetValueFromMainAstroWatchTime:@selector(watchTimeWithNextSunset)];
}
EBVM_OP1(nextSunsetDayOffsetN, timerNumber)
{
    return [[virtualMachine owner] getDayOffsetValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextSunset)];
}
EBVM_OP0(nextSunsetValid)
{
    return [[[virtualMachine owner] mainAstro] nextSunsetValid];
}
EBVM_OP1(nextSunsetValidN, timerNumber)
{
    return [[[virtualMachine owner] astroWithIndex:timerNumber] nextSunsetValid];
}

EBVM_OP0(moonAgeAngle)
{
    return [[[virtualMachine owner] mainAstro] moonAgeAngle];
}
EBVM_OP0(realMoonAgeAngle) 
{
    return [[[virtualMachine owner] mainAstro] realMoonAgeAngle];
}
EBVM_OP1(moonAgeAngleN, timerNumber)
{
    return [[[virtualMachine owner] astroWithIndex:timerNumber] moonAgeAngle];
}

EBVM_OP0(moonHourAngle)
{
    return ((2 * M_PI / 24) * [[virtualMachine owner] getValueFromMainTime:@selector(hour24ValueUsingEnv:)]) - [[[virtualMachine owner] mainAstro] moonAgeAngle];
}
EBVM_OP1(moonHourAngleN, timerNumber)
{
    return ((2 * M_PI / 24) * [[virtualMachine owner] getValueFromTimeForEnv:timerNumber watchTimeSelector:@selector(hour24ValueUsingEnv:)]) - [[[virtualMachine owner] mainAstro] moonAgeAngle];
}

EBVM_OP1(moonAgeNumberAngle, n)
{
    return round(([[[virtualMachine owner] mainAstro] moonAgeAngle]-M_PI/2)*n/(2*M_PI))*2*M_PI/n;
}
EBVM_OP2(moonAgeNumberAngleN, n, timerNumber)
{
    return round(([[[virtualMachine owner] astroWithIndex:timerNumber] moonAgeAngle]-M_PI/2)*n/(2*M_PI))*2*M_PI/n;
}

EBVM_OP0(moonPositionAngle)
{
    return [[[virtualMachine owner] mainAstro] moonPositionAngle];
}
EBVM_OP1(moonPositionAngleN, timerNumber)
{
    return [[[virtualMachine owner] astroWithIndex:timerNumber] moonPositionAngle];
}

EBVM_OP0(moonRelativePositionAngle)
{
    return [[[virtualMachine owner] mainAstro] moonRelativePositionAngle];
}
EBVM_OP1(moonRelativePositionAngleN, timerNumber)
{
    return [[[virtualMachine owner] astroWithIndex:timerNumber] moonRelativePositionAngle];
}

EBVM_OP0(moonRelativeAngle)
{
    return [[[virtualMachine owner] mainAstro] moonRelativeAngle];
}
EBVM_OP1(moonRelativeAngleN, timerNumber)
{
    return [[[virtualMachine owner] astroWithIndex:timerNumber] moonRelativeAngle];
}

EBVM_OP0(sunRA)
{
    return [[[virtualMachine owner] mainAstro] sunRA];
}
EBVM_OP1(sunRAN, timerNumber)
{
    return [[[virtualMachine owner] astroWithIndex:timerNumber] sunRA];
}

EBVM_OP0(sunDec)
{
    return [[[virtualMachine owner] mainAstro] sunDecl];
}
EBVM_OP1(sunDecN, timerNumber)
{
    return [[[virtualMachine owner] astroWithIndex:timerNumber] sunDecl];
}

EBVM_OP0(moonRA)
{
    return [[[virtualMachine owner] mainAstro] moonRA];
}
EBVM_OP1(moonRAN, timerNumber)
{
    return [[[virtualMachine owner] astroWithIndex:timerNumber] moonRA];
}

EBVM_OP0(moonDec)
{
    return [[[virtualMachine owner] mainAstro] moonDecl];
}
EBVM_OP1(moonDecN, timerNumber)
{
    return [[[virtualMachine owner] astroWithIndex:timerNumber] moonDecl];
}

EBVM_OP0(sunAzimuth)
{
    return [[[virtualMachine owner] mainAstro] sunAzimuth];
}
EBVM_OP1(sunAzimuthN, timerNumber)
{
    return [[[virtualMachine owner] astroWithIndex:timerNumber] sunAzimuth];
}

EBVM_OP0(sunAltitude)
{
    return [[[virtualMachine owner] mainAstro] sunAltitude];
}
EBVM_OP1(sunAltitudeN, timerNumber)
{
    return [[[virtualMachine owner] astroWithIndex:timerNumber] sunAltitude];
}

EBVM_OP0(moonAzimuth)
{
    return [[[virtualMachine owner] mainAstro] moonAzimuth];
}
EBVM_OP1(moonAzimuthN, timerNumber)
{
    return [[[virtualMachine owner] astroWithIndex:timerNumber] moonAzimuth];
}

EBVM_OP0(moonAltitude)
{
    return [[[virtualMachine owner] mainAstro] moonAltitude];
}
EBVM_OP1(moonAltitudeN, timerNumber)
{
    return [[[virtualMachine owner] astroWithIndex:timerNumber] moonAltitude];
}

EBVM_OP0(lunarAscendingNodeRA)
{
    return [[[virtualMachine owner] mainAstro] moonAscendingNodeRA];
}

EBVM_OP0(lunarAscendingNodeLongitude)
{
    return [[[virtualMachine owner] mainAstro] moonAscendingNodeLongitude];
}

EBVM_OP0(azimuthOfHighestEclipticAltitude)
{
    return [[[virtualMachine owner] mainAstro] azimuthOfHighestEclipticAltitude];
}

EBVM_OP0(eclipticAltitude)
{
    return [[[virtualMachine owner] mainAstro] eclipticAltitude];
}

EBVM_OP0(longitudeAtNorthMeridian)
{
    return [[[virtualMachine owner] mainAstro] longitudeAtNorthMeridian];
}

static bool eclipticIncreasesLeftToRight(ECWatchEnvironment *enviro)
{
    ECLocationManager *locationManager = [enviro locationManager];
    double observerLatitude = [locationManager lastLatitudeRadians];
    if (fabs(observerLatitude) > M_PI / 4) {
	return (observerLatitude < 0);  // In the north, the ecliptic increases right to left
    } else {
	double azimuth = [[enviro astronomyManager] azimuthOfHighestEclipticAltitude];
	if (azimuth < M_PI / 2 || azimuth > 3 * M_PI / 2) {  // more north than south, so it's like being in the southern hemisphere
	    return true;
	} else {  // more south than north, so like being in the northern hemisphere
	    return false;
	}
    }
}

EBVM_OP0(eclipticIncreasesLeftToRight)
{
    return eclipticIncreasesLeftToRight([[virtualMachine owner] enviroWithIndex:0]);
}

EBVM_OP0(apparentEclipticSign)
{
    bool increasesLeftToRight = eclipticIncreasesLeftToRight([[virtualMachine owner] enviroWithIndex:0]);
    return increasesLeftToRight ? 1 : -1;
}

EBVM_OP0(longitudeOfHighestEclipticAltitude)
{
    return [[[virtualMachine owner] mainAstro] longitudeOfHighestEclipticAltitude];
}

EBVM_OP0(offsetOfWinterSolsticeFromDec31Midnight)
{
    double northSouthOffset = 0;
    ECLocationManager *locationManager = [[[virtualMachine owner] enviroWithIndex:0] locationManager];
    if ([locationManager valid]) {
	//printAngle([locationManager lastLatitudeRadians], "latitude");
	northSouthOffset = [locationManager lastLatitudeRadians] >= 0 ? 0 : M_PI;		    // equator is north
    }
    return [[[virtualMachine owner] mainAstro] calendarErrorVsTropicalYear] - 10.25/365.25*2*M_PI + northSouthOffset;	// subtract a bit to move the winter solstice (unrotated position of the hand graphic) back to Dec 21 for the Gregorian epoch
}

EBVM_OP1(closestSunEclipticLongitudeQuarter366IndicatorFraction, quarterNumber)
{
    return [[[virtualMachine owner] mainAstro] closestSunEclipticLongitudeQuarter366IndicatorAngle:quarterNumber] / (M_PI * 2);
}

EBVM_OP1(closestSunEclipticLongitudeQuarter366IndicatorAngle, quarterNumber)
{
    return [[[virtualMachine owner] mainAstro] closestSunEclipticLongitudeQuarter366IndicatorAngle:quarterNumber];
}

EBVM_OP0(year366IndicatorFraction)
{
    return [[virtualMachine owner] getValueFromMainTime:@selector(year366IndicatorFractionUsingEnv:)];
}

EBVM_OP0(year366IndicatorAngle)
{
    return [[virtualMachine owner] getValueFromMainTime:@selector(year366IndicatorFractionUsingEnv:)] * 2 * M_PI;
}

EBVM_OP1(RAOfPlanet, planetNumber)	// right ascension (radians)
{
    switch ((int)planetNumber) {
      case ECPlanetSun:
	return [[[virtualMachine owner] mainAstro] sunRA];
      case ECPlanetMoon:
	return [[[virtualMachine owner] mainAstro] moonRA];
      case ECPlanetMercury:
      case ECPlanetVenus:
      case ECPlanetMars:
      case ECPlanetJupiter:
      case ECPlanetSaturn:
      case ECPlanetUranus:
      case ECPlanetNeptune:
	return [[[virtualMachine owner] mainAstro] planetRA:planetNumber correctForParallax:false];
      case ECPlanetEarth:
      case ECPlanetPluto:
      default:
	assert(false);
	return 0;
    }
}
EBVM_OP1(declOfPlanet, planetNumber)	// declination (radians)
{
    switch ((int)planetNumber) {
      case ECPlanetSun:
	return [[[virtualMachine owner] mainAstro] sunDecl];
      case ECPlanetMoon:
	return [[[virtualMachine owner] mainAstro] moonDecl];
      case ECPlanetMercury:
      case ECPlanetVenus:
      case ECPlanetMars:
      case ECPlanetJupiter:
      case ECPlanetSaturn:
      case ECPlanetUranus:
      case ECPlanetNeptune:
	return [[[virtualMachine owner] mainAstro] planetDecl:planetNumber correctForParallax:false];
      case ECPlanetEarth:
      case ECPlanetPluto:
      default:
	assert(false);
	return 0;
    }
}
EBVM_OP1(azimuthOfPlanet, planetNumber)	    // radians
{
    switch ((int)planetNumber) {
      case ECPlanetSun:
	return [[[virtualMachine owner] mainAstro] sunAzimuth];
      case ECPlanetMoon:
	return [[[virtualMachine owner] mainAstro] moonAzimuth];
      case ECPlanetMercury:
      case ECPlanetVenus:
      case ECPlanetMars:
      case ECPlanetJupiter:
      case ECPlanetSaturn:
      case ECPlanetUranus:
      case ECPlanetNeptune:
	return [[[virtualMachine owner] mainAstro] planetAzimuth:planetNumber];
      case ECPlanetPluto:
      case ECPlanetEarth:
	default:
	  assert(false);
	  return 0;
    }
}
EBVM_OP1(altitudeOfPlanet, planetNumber)    // radians
{
    switch ((int)planetNumber) {
      case ECPlanetSun:
	return [[[virtualMachine owner] mainAstro] sunAltitude];
      case ECPlanetMoon:
	return [[[virtualMachine owner] mainAstro] moonAltitude];
      case ECPlanetMercury:
      case ECPlanetVenus:
      case ECPlanetMars:
      case ECPlanetJupiter:
      case ECPlanetSaturn:
      case ECPlanetUranus:
      case ECPlanetNeptune:
	return [[[virtualMachine owner] mainAstro] planetAltitude:planetNumber];
      case ECPlanetPluto:
      case ECPlanetEarth:
	default:
	  assert(false);
	  return 0;
    }
}
EBVM_OP1(ELongitudeOfPlanet, planetNumber)	// ecliptic longitude (radians)
{
    switch ((int)planetNumber) {
      case ECPlanetSun:
      case ECPlanetMoon:
      case ECPlanetMercury:
      case ECPlanetVenus:
      case ECPlanetMars:
      case ECPlanetJupiter:
      case ECPlanetSaturn:
      case ECPlanetUranus:
      case ECPlanetNeptune:
	return [[[virtualMachine owner] mainAstro] planetEclipticLongitude:planetNumber];
      case ECPlanetPluto:
      case ECPlanetEarth:
      default:
	assert(false);
	return 0;
    }
}
EBVM_OP1(ELatitudeOfPlanet, planetNumber)	    // ecliptic latitude (radians)
{
    switch ((int)planetNumber) {
      case ECPlanetSun:
      case ECPlanetMoon:
      case ECPlanetMercury:
      case ECPlanetVenus:
      case ECPlanetMars:
      case ECPlanetJupiter:
      case ECPlanetSaturn:
      case ECPlanetUranus:
      case ECPlanetNeptune:
	return [[[virtualMachine owner] mainAstro] planetEclipticLatitude:planetNumber];
      case ECPlanetPluto:
      case ECPlanetEarth:
      default:
	assert(false);
	return 0;
    }
}
EBVM_OP1(HLongitudeOfPlanet, planetNumber)	    // heliocentric longitude
{
    switch ((int)planetNumber) {
      case ECPlanetMercury:
      case ECPlanetVenus:
      case ECPlanetEarth:
      case ECPlanetMars:
      case ECPlanetJupiter:
      case ECPlanetSaturn:
      case ECPlanetUranus:
      case ECPlanetNeptune:
	return [[[virtualMachine owner] mainAstro] planetHeliocentricLongitude:planetNumber];
      case ECPlanetMoon:
      case ECPlanetSun:    
      case ECPlanetPluto:
      default:
	assert(false);
	return 0;
    }
}
EBVM_OP1(HLatitudeOfPlanet, planetNumber)	    // heliocentric latitude
{
    switch ((int)planetNumber) {
      case ECPlanetEarth:
      case ECPlanetMercury:
      case ECPlanetVenus:
      case ECPlanetMars:
      case ECPlanetJupiter:
      case ECPlanetSaturn:
      case ECPlanetUranus:
      case ECPlanetNeptune:
	return [[[virtualMachine owner] mainAstro] planetHeliocentricLatitude:planetNumber];
      case ECPlanetMoon:
      case ECPlanetSun:    
      case ECPlanetPluto:
      default:
	assert(false);
	return 0;
    }
}
EBVM_OP1(distanceFromSunOfPlanet, planetNumber)		// in km
{
    switch ((int)planetNumber) {
      case ECPlanetMercury:
      case ECPlanetVenus:
      case ECPlanetEarth:
      case ECPlanetMars:
      case ECPlanetJupiter:
      case ECPlanetSaturn:
      case ECPlanetUranus:
      case ECPlanetNeptune:
	return [[[virtualMachine owner] mainAstro] planetHeliocentricRadius:planetNumber];
      case ECPlanetPluto:
      case ECPlanetSun:
      case ECPlanetMoon:
      default:
	assert(false);
	return 0;
    }
}
EBVM_OP1(distanceFromEarthOfPlanet, planetNumber)   // kilometers
{
    switch ((int)planetNumber) {
      case ECPlanetSun:
      case ECPlanetMoon:
      case ECPlanetMercury:
      case ECPlanetVenus:
      case ECPlanetMars:
      case ECPlanetJupiter:
      case ECPlanetSaturn:
      case ECPlanetUranus:
      case ECPlanetNeptune:
	return [[[virtualMachine owner] mainAstro] planetGeocentricDistance:planetNumber];
      case ECPlanetPluto:
      case ECPlanetEarth:   
      default:
	assert(false);
	return 0;
    }
}
EBVM_OP1(riseOfPlanetForDayHour24Number, planetNumber)
{
    switch ((int)planetNumber) {
	case ECPlanetMercury:
    	case ECPlanetVenus:
    	case ECPlanetMars:
    	case ECPlanetJupiter:
    	case ECPlanetSaturn:
    	case ECPlanetUranus:
       	case ECPlanetNeptune:
	  return [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithPlanetriseForDay:) planetNumber:planetNumber watchTimeSelector:@selector(hour24NumberUsingEnv:)];
	case ECPlanetMoon:
	  return [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithMoonriseForDay) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
	case ECPlanetSun:
	  return [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithSunriseForDay) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
	case ECPlanetEarth:
       	case ECPlanetPluto:
	default:
	  assert(false);
	  return 0;
    }
}
EBVM_OP1(riseOfPlanetForDayHour24ValueAngle, planetNumber)
{
    switch ((int)planetNumber) {
	case ECPlanetMercury:
    	case ECPlanetVenus:
    	case ECPlanetMars:
    	case ECPlanetJupiter:
    	case ECPlanetSaturn:
    	case ECPlanetUranus:
       	case ECPlanetNeptune:
	  return (2 * M_PI / 24) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithPlanetriseForDay:) planetNumber:planetNumber watchTimeSelector:@selector(hour24ValueUsingEnv:)];
	case ECPlanetMoon:
	  return (2 * M_PI / 24) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithMoonriseForDay) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
	case ECPlanetSun:
	  return (2 * M_PI / 24) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithSunriseForDay) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
	case ECPlanetEarth:
       	case ECPlanetPluto:
	default:
	  assert(false);
	  return 0;
    }
}
EBVM_OP1(riseOfPlanetForDayHour12ValueAngle, planetNumber)
{
    switch ((int)planetNumber) {
	case ECPlanetMercury:
    	case ECPlanetVenus:
    	case ECPlanetMars:
    	case ECPlanetJupiter:
    	case ECPlanetSaturn:
    	case ECPlanetUranus:
       	case ECPlanetNeptune:
	  return (2 * M_PI / 12) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithPlanetriseForDay:) planetNumber:planetNumber watchTimeSelector:@selector(hour12ValueUsingEnv:)];
	case ECPlanetMoon:
	  return (2 * M_PI / 12) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithMoonriseForDay) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
	case ECPlanetSun:
	  return (2 * M_PI / 12) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithSunriseForDay) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
	case ECPlanetEarth:
       	case ECPlanetPluto:
	default:
	  assert(false);
	  return 0;
    }
}
EBVM_OP1(riseOfPlanetForDayMinuteValueAngle, planetNumber)
{
    switch ((int)planetNumber) {
	case ECPlanetMercury:
    	case ECPlanetVenus:
    	case ECPlanetMars:
    	case ECPlanetJupiter:
    	case ECPlanetSaturn:
    	case ECPlanetUranus:
       	case ECPlanetNeptune:
	  return (2 * M_PI / 60) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithPlanetriseForDay:) planetNumber:planetNumber watchTimeSelector:@selector(minuteValueUsingEnv:)];
	case ECPlanetMoon:
	  return (2 * M_PI / 60) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithMoonriseForDay) watchTimeSelector:@selector(minuteValueUsingEnv:)];
	case ECPlanetSun:
	  return (2 * M_PI / 60) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithSunriseForDay) watchTimeSelector:@selector(minuteValueUsingEnv:)];
	case ECPlanetEarth:
       	case ECPlanetPluto:
	default:
	  assert(false);
	  return 0;
    }
}
EBVM_OP1(transitOfPlanetForDayHour24Number, planetNumber)
{
    switch ((int)planetNumber) {
	case ECPlanetMercury:
    	case ECPlanetVenus:
    	case ECPlanetMars:
    	case ECPlanetJupiter:
    	case ECPlanetSaturn:
    	case ECPlanetUranus:
       	case ECPlanetNeptune:
	  return [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithPlanettransitForDay:) planetNumber:planetNumber watchTimeSelector:@selector(hour24NumberUsingEnv:)];
	case ECPlanetMoon:
	  return [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithMoontransitForDay) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
	case ECPlanetSun:
	  return [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithSuntransitForDay) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
	case ECPlanetEarth:
       	case ECPlanetPluto:
	default:
	  assert(false);
	  return 0;
    }
}
EBVM_OP1(transitOfPlanetForDayHour24ValueAngle, planetNumber)
{
    switch ((int)planetNumber) {
	case ECPlanetMercury:
    	case ECPlanetVenus:
    	case ECPlanetMars:
    	case ECPlanetJupiter:
    	case ECPlanetSaturn:
    	case ECPlanetUranus:
       	case ECPlanetNeptune:
	  return (2 * M_PI / 24) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithPlanettransitForDay:) planetNumber:planetNumber watchTimeSelector:@selector(hour24ValueUsingEnv:)];
	case ECPlanetMoon:
	  return (2 * M_PI / 24) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithMoontransitForDay) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
	case ECPlanetSun:
	  return (2 * M_PI / 24) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithSuntransitForDay) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
	case ECPlanetEarth:
       	case ECPlanetPluto:
	default:
	  assert(false);
	  return 0;
    }
}
EBVM_OP1(transitOfPlanetForDayHour12ValueAngle, planetNumber)
{
    switch ((int)planetNumber) {
	case ECPlanetMercury:
    	case ECPlanetVenus:
    	case ECPlanetMars:
    	case ECPlanetJupiter:
    	case ECPlanetSaturn:
    	case ECPlanetUranus:
       	case ECPlanetNeptune:
	  return (2 * M_PI / 12) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithPlanettransitForDay:) planetNumber:planetNumber watchTimeSelector:@selector(hour12ValueUsingEnv:)];
	case ECPlanetMoon:
	  return (2 * M_PI / 12) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithMoontransitForDay) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
	case ECPlanetSun:
	  return (2 * M_PI / 12) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithSuntransitForDay) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
	case ECPlanetEarth:
       	case ECPlanetPluto:
	default:
	  assert(false);
	  return 0;
    }
}
EBVM_OP1(transitOfPlanetForDayMinuteValueAngle, planetNumber)
{
    switch ((int)planetNumber) {
	case ECPlanetMercury:
    	case ECPlanetVenus:
    	case ECPlanetMars:
    	case ECPlanetJupiter:
    	case ECPlanetSaturn:
    	case ECPlanetUranus:
       	case ECPlanetNeptune:
	  return (2 * M_PI / 60) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithPlanettransitForDay:) planetNumber:planetNumber watchTimeSelector:@selector(minuteValueUsingEnv:)];
	case ECPlanetMoon:
	  return (2 * M_PI / 60) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithMoontransitForDay) watchTimeSelector:@selector(minuteValueUsingEnv:)];
	case ECPlanetSun:
	  return (2 * M_PI / 60) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithSuntransitForDay) watchTimeSelector:@selector(minuteValueUsingEnv:)];
	case ECPlanetEarth:
       	case ECPlanetPluto:
	default:
	  assert(false);
	  return 0;
    }
}
EBVM_OP1(setOfPlanetForDayHour12ValueAngle, planetNumber)
{
    switch ((int)planetNumber) {
	case ECPlanetMercury:
    	case ECPlanetVenus:
    	case ECPlanetMars:
    	case ECPlanetJupiter:
    	case ECPlanetSaturn:
    	case ECPlanetUranus:
       	case ECPlanetNeptune:
	  return (2 * M_PI / 12) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithPlanetsetForDay:) planetNumber:planetNumber watchTimeSelector:@selector(hour12ValueUsingEnv:)];
	case ECPlanetMoon:
	  return (2 * M_PI / 12) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithMoonsetForDay) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
	case ECPlanetSun:
	  return (2 * M_PI / 12) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithSunsetForDay) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
	case ECPlanetEarth:
       	case ECPlanetPluto:
	default:
	  assert(false);
	  return 0;
    }
}
EBVM_OP1(setOfPlanetForDayHour24Number, planetNumber)
{
    switch ((int)planetNumber) {
	case ECPlanetMercury:
    	case ECPlanetVenus:
    	case ECPlanetMars:
    	case ECPlanetJupiter:
    	case ECPlanetSaturn:
    	case ECPlanetUranus:
       	case ECPlanetNeptune:
	  return [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithPlanetsetForDay:) planetNumber:planetNumber watchTimeSelector:@selector(hour24NumberUsingEnv:)];
	case ECPlanetMoon:
	  return [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithMoonsetForDay) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
	case ECPlanetSun:
	  return [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithSunsetForDay) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
	case ECPlanetEarth:
       	case ECPlanetPluto:
	default:
	  assert(false);
	  return 0;
    }
}
EBVM_OP1(setOfPlanetForDayHour24ValueAngle, planetNumber)
{
    switch ((int)planetNumber) {
	case ECPlanetMercury:
    	case ECPlanetVenus:
    	case ECPlanetMars:
    	case ECPlanetJupiter:
    	case ECPlanetSaturn:
    	case ECPlanetUranus:
       	case ECPlanetNeptune:
	  return (2 * M_PI / 24) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithPlanetsetForDay:) planetNumber:planetNumber watchTimeSelector:@selector(hour24ValueUsingEnv:)];
	case ECPlanetMoon:
	  return (2 * M_PI / 24) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithMoonsetForDay) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
	case ECPlanetSun:
	  return (2 * M_PI / 24) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithSunsetForDay) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
	case ECPlanetEarth:
       	case ECPlanetPluto:
	default:
	  assert(false);
	  return 0;
    }
}
EBVM_OP1(setOfPlanetForDayMinuteValueAngle, planetNumber)
{
    switch ((int)planetNumber) {
	case ECPlanetMercury:
    	case ECPlanetVenus:
    	case ECPlanetMars:
    	case ECPlanetJupiter:
    	case ECPlanetSaturn:
    	case ECPlanetUranus:
       	case ECPlanetNeptune:
	  return (2 * M_PI / 60) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithPlanetsetForDay:) planetNumber:planetNumber watchTimeSelector:@selector(minuteValueUsingEnv:)];
	case ECPlanetMoon:
	  return (2 * M_PI / 60) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithMoonsetForDay) watchTimeSelector:@selector(minuteValueUsingEnv:)];
	case ECPlanetSun:
	  return (2 * M_PI / 60) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithSunsetForDay) watchTimeSelector:@selector(minuteValueUsingEnv:)];
	case ECPlanetEarth:
       	case ECPlanetPluto:
	default:
	  assert(false);
	  return 0;
    }
}

EBVM_OP0(J2000RAofVernalEquinoxOfDateAngle)
{
    return -[[[virtualMachine owner] mainAstro] precession];
}

EBVM_OP0(season)
#define spring 0
#define summer 1
#define fall   2
#define winter 3
{
    bool north = true;							    // invalid is north
    ECLocationManager *locationManager = [[[virtualMachine owner] enviroWithIndex:0] locationManager];
    if ([locationManager valid]) {
	//printAngle([locationManager lastLatitudeRadians], "latitude");
	north = [locationManager lastLatitudeRadians] >= 0;		    // equator is north
    }
    double pa =[[[virtualMachine owner] mainAstro] planetEclipticLongitude:ECPlanetSun];

    if (pa > M_PI*3/2)
	return north ? winter : summer;
    else if (pa > M_PI)
	return north ? fall : spring;
    else if (pa > M_PI/2)
	return north ? summer : winter;
    else
	return north ? spring : fall;
}
#undef spring
#undef summer
#undef fall
#undef winter

EBVM_OP0(EOTAngle)
{
    return   [[[virtualMachine owner] mainAstro] EOT];
}

EBVM_OP1(EOTAngleN, timerNumber)
{
    return   [[[virtualMachine owner] astroWithIndex:timerNumber] EOT];
}

EBVM_OP0(EOTValue)
{
    return   [[[virtualMachine owner] mainAstro] EOT] * 12 * 3600 / M_PI;
}

EBVM_OP1(EOTValueN, timerNumber)
{
    return   [[[virtualMachine owner] astroWithIndex:timerNumber] EOT] * 12 * 3600 / M_PI;
}

EBVM_OP0(vernalEquinoxAngle)
{
    return [[[virtualMachine owner] mainAstro] vernalEquinoxAngle];
}

EBVM_OP1(vernalEquinoxAngleN, timerNumber)
{
    return [[[virtualMachine owner] astroWithIndex:timerNumber] vernalEquinoxAngle];
}

// 12:35:45 => 35
EBVM_OP0(moonriseForDayMinuteNumber)
{
    return [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithMoonriseForDay) watchTimeSelector:@selector(minuteNumberUsingEnv:)];
}
EBVM_OP1(moonriseForDayMinuteNumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithMoonriseForDay) watchTimeSelector:@selector(minuteNumberUsingEnv:)];
}
EBVM_OP0(moonriseForDayMinuteNumberAngle)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithMoonriseForDay) watchTimeSelector:@selector(minuteNumberUsingEnv:)];
}
EBVM_OP1(moonriseForDayMinuteNumberAngleN, timerNumber)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithMoonriseForDay) watchTimeSelector:@selector(minuteNumberUsingEnv:)];
}

// 12:35:45 => 35.75
EBVM_OP0(moonriseForDayMinuteValue)
{
    return [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithMoonriseForDay) watchTimeSelector:@selector(minuteValueUsingEnv:)];
}
EBVM_OP1(moonriseForDayMinuteValueN, timerNumber)
{
    return [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithMoonriseForDay) watchTimeSelector:@selector(minuteValueUsingEnv:)];
}
EBVM_OP0(moonriseForDayMinuteValueAngle)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithMoonriseForDay) watchTimeSelector:@selector(minuteValueUsingEnv:)];
}
EBVM_OP1(moonriseForDayMinuteValueAngleN, timerNumber)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithMoonriseForDay) watchTimeSelector:@selector(minuteValueUsingEnv:)];
}

// 13:45:00 => 1
EBVM_OP0(moonriseForDayHour12Number)
{
    return [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithMoonriseForDay) watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}
EBVM_OP1(moonriseForDayHour12NumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithMoonriseForDay) watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}
EBVM_OP0(moonriseForDayHour12NumberAngle)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithMoonriseForDay) watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}
EBVM_OP1(moonriseForDayHour12NumberAngleN, timerNumber)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithMoonriseForDay) watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}

// 13:45:00 => 1.75
EBVM_OP0(moonriseForDayHour12Value)
{
    return [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithMoonriseForDay) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}
EBVM_OP1(moonriseForDayHour12ValueN, timerNumber)
{
    return [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithMoonriseForDay) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}
EBVM_OP0(moonriseForDayHour12ValueAngle)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithMoonriseForDay) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}
EBVM_OP1(moonriseForDayHour12ValueAngleN, timerNumber)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithMoonriseForDay) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}

// 13:45:00 => 13
EBVM_OP0(moonriseForDayHour24Number)
{
    return [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithMoonriseForDay) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}
EBVM_OP1(moonriseForDayHour24NumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithMoonriseForDay) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}
EBVM_OP0(moonriseForDayHour24NumberAngle)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithMoonriseForDay) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}
EBVM_OP1(moonriseForDayHour24NumberAngleN, timerNumber)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithMoonriseForDay) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}

// 13:45:00 => 13.75
EBVM_OP0(moonriseForDayHour24Value)
{
    return [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithMoonriseForDay) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}
EBVM_OP1(moonriseForDayHour24ValueN, timerNumber)
{
    return [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithMoonriseForDay) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}
EBVM_OP0(moonriseForDayHour24ValueAngle)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithMoonriseForDay) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}
EBVM_OP1(moonriseForDayHour24ValueAngleN, timerNumber)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithMoonriseForDay) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}

EBVM_OP0(moonriseForDayValid)
{
    return [[[virtualMachine owner] mainAstro] moonriseForDayValid];
}

EBVM_OP0(polarSummer)
{
    return [[[virtualMachine owner] mainAstro] polarSummer];
}

EBVM_OP0(polarWinter)
{
    return [[[virtualMachine owner] mainAstro] polarWinter];
}

EBVM_OP1(riseOfPlanetForDayValid, planetNumber)
{
    switch ((int)planetNumber) {
	case ECPlanetMercury:
    	case ECPlanetVenus:
    	case ECPlanetMars:
    	case ECPlanetJupiter:
    	case ECPlanetSaturn:
    	case ECPlanetUranus:
       	case ECPlanetNeptune:
	  return [[[virtualMachine owner] mainAstro] planetriseForDayValid:planetNumber];
	case ECPlanetMoon:
	  return [[[virtualMachine owner] mainAstro] moonriseForDayValid];
	case ECPlanetSun:
	  return [[[virtualMachine owner] mainAstro] sunriseForDayValid];
	case ECPlanetEarth:
       	case ECPlanetPluto:
	default:
	  assert(false);
	  return 0;
    }
}

EBVM_OP1(setOfPlanetForDayValid, planetNumber)
{
    switch ((int)planetNumber) {
	case ECPlanetMercury:
    	case ECPlanetVenus:
    	case ECPlanetMars:
    	case ECPlanetJupiter:
    	case ECPlanetSaturn:
    	case ECPlanetUranus:
       	case ECPlanetNeptune:
	  return [[[virtualMachine owner] mainAstro] planetsetForDayValid:planetNumber];
	case ECPlanetMoon:
	  return [[[virtualMachine owner] mainAstro] moonsetForDayValid];
	case ECPlanetSun:
	  return [[[virtualMachine owner] mainAstro] sunsetForDayValid];
	case ECPlanetEarth:
       	case ECPlanetPluto:
	default:
	  assert(false);
	  return 0;
    }
}

EBVM_OP1(transitOfPlanetForDayValid, planetNumber)
{
    switch ((int)planetNumber) {
      case ECPlanetMercury:
      case ECPlanetVenus:
      case ECPlanetMars:
      case ECPlanetJupiter:
      case ECPlanetSaturn:
      case ECPlanetUranus:
      case ECPlanetNeptune:
	return [[[virtualMachine owner] mainAstro] planettransitForDayValid:planetNumber];
      case ECPlanetMoon:
	return [[[virtualMachine owner] mainAstro] moontransitForDayValid];
      case ECPlanetSun:
	return [[[virtualMachine owner] mainAstro] suntransitForDayValid];
      case ECPlanetEarth:
      case ECPlanetPluto:
      default:
	assert(false);
	return 0;
    }
}

EBVM_OP1(moonriseForDayValidN, timerNumber)
{
    return [[[virtualMachine owner] astroWithIndex:timerNumber] moonriseForDayValid];
}

// designed specially for Mauna Kea
EBVM_OP0(sunriseIndicatorValid)
{
    return [[[virtualMachine owner] mainAstro] sunriseIndicatorValid];
}
EBVM_OP0(sunsetIndicatorValid)
{
    return [[[virtualMachine owner] mainAstro] sunsetIndicatorValid];
}
EBVM_OP0(sunrise24HourIndicatorAngle)
{
    return [[[virtualMachine owner] mainAstro] sunrise24HourIndicatorAngle];
}
EBVM_OP1(sunrise24HourIndicatorAngleN, timerNumber)
{
    return [[[virtualMachine owner] astroWithIndex:timerNumber] sunrise24HourIndicatorAngle];
}
EBVM_OP0(sunset24HourIndicatorAngle)
{
    return [[[virtualMachine owner] mainAstro] sunset24HourIndicatorAngle];
}
EBVM_OP1(sunset24HourIndicatorAngleN, timerNumber)
{
    return [[[virtualMachine owner] astroWithIndex:timerNumber] sunset24HourIndicatorAngle];
}
EBVM_OP0(moonrise24HourIndicatorAngle)
{
    return [[[virtualMachine owner] mainAstro] moonrise24HourIndicatorAngle];
}
EBVM_OP1(moonrise24HourIndicatorAngleN, timerNumber)
{
    return [[[virtualMachine owner] astroWithIndex:timerNumber] moonrise24HourIndicatorAngle];
}
EBVM_OP0(moonset24HourIndicatorAngle)
{
    return [[[virtualMachine owner] mainAstro] moonset24HourIndicatorAngle];
}
EBVM_OP1(moonset24HourIndicatorAngleN, timerNumber)
{
    return [[[virtualMachine owner] astroWithIndex:timerNumber] moonset24HourIndicatorAngle];
}
EBVM_OP1(planetrise24HourIndicatorAngle, planetNumber)
{
    return [[[virtualMachine owner] mainAstro] planetrise24HourIndicatorAngle:planetNumber];
}
EBVM_OP2(planetrise24HourIndicatorAngleN, planetNumber, timerNumber)
{
    return [[[virtualMachine owner] astroWithIndex:timerNumber] planetrise24HourIndicatorAngle:planetNumber];
}
EBVM_OP1(planetset24HourIndicatorAngle, planetNumber)
{
    return [[[virtualMachine owner] mainAstro] planetset24HourIndicatorAngle:planetNumber];
}
EBVM_OP2(planetset24HourIndicatorAngleN, planetNumber, timerNumber)
{
    return [[[virtualMachine owner] astroWithIndex:timerNumber] planetset24HourIndicatorAngle:planetNumber];
}
EBVM_OP2(planettransit24HourIndicatorAngle, planetNumber, numLeaves)
{
    return [[[virtualMachine owner] mainAstro] planettransit24HourIndicatorAngle:planetNumber forNumLeaves:numLeaves];
}
EBVM_OP1(planetrise24HourIndicatorAngleLST, planetNumber)
{
    return [[[virtualMachine owner] mainAstro] planetrise24HourIndicatorAngleLST:planetNumber];
}
EBVM_OP1(planetset24HourIndicatorAngleLST, planetNumber)
{
    return [[[virtualMachine owner] mainAstro] planetset24HourIndicatorAngleLST:planetNumber];
}

EBVM_OP0(moonNoonAngle)
{
    static double prevTime, result;		    // a really really simple cache
    double now = [[[virtualMachine owner] mainTime] currentTime];
    if (fabs(now - prevTime) < 1) {		    // allow 1 second slop for astronomy calcs
	// printf("returning previous moonNoonAngle\n");
    } else {
	double moonRise = [[[virtualMachine owner] mainAstro] moonrise24HourIndicatorAngle];
	double moonSet =  [[[virtualMachine owner] mainAstro] moonset24HourIndicatorAngle];
	if (moonRise == moonSet) {
	    result = 0;
	} else {
	    if (moonRise > moonSet) {
		moonSet += (2 * M_PI);
	    }
	    result = (moonRise + moonSet) / 2;
	    prevTime = now;
	}
    }
    return result;
}

// 12:35:45 => 35
EBVM_OP0(moonsetForDayMinuteNumber)
{
    return [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithMoonsetForDay) watchTimeSelector:@selector(minuteNumberUsingEnv:)];
}
EBVM_OP1(moonsetForDayMinuteNumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithMoonsetForDay) watchTimeSelector:@selector(minuteNumberUsingEnv:)];
}
EBVM_OP0(moonsetForDayMinuteNumberAngle)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithMoonsetForDay) watchTimeSelector:@selector(minuteNumberUsingEnv:)];
}
EBVM_OP1(moonsetForDayMinuteNumberAngleN, timerNumber)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithMoonsetForDay) watchTimeSelector:@selector(minuteNumberUsingEnv:)];
}

// 12:35:45 => 35.75
EBVM_OP0(moonsetForDayMinuteValue)
{
    return [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithMoonsetForDay) watchTimeSelector:@selector(minuteValueUsingEnv:)];
}
EBVM_OP1(moonsetForDayMinuteValueN, timerNumber)
{
    return [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithMoonsetForDay) watchTimeSelector:@selector(minuteValueUsingEnv:)];
}
EBVM_OP0(moonsetForDayMinuteValueAngle)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithMoonsetForDay) watchTimeSelector:@selector(minuteValueUsingEnv:)];
}
EBVM_OP1(moonsetForDayMinuteValueAngleN, timerNumber)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithMoonsetForDay) watchTimeSelector:@selector(minuteValueUsingEnv:)];
}

// 13:45:00 => 1
EBVM_OP0(moonsetForDayHour12Number)
{
    return [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithMoonsetForDay) watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}
EBVM_OP1(moonsetForDayHour12NumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithMoonsetForDay) watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}
EBVM_OP0(moonsetForDayHour12NumberAngle)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithMoonsetForDay) watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}
EBVM_OP1(moonsetForDayHour12NumberAngleN, timerNumber)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithMoonsetForDay) watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}

// 13:45:00 => 1.75
EBVM_OP0(moonsetForDayHour12Value)
{
    return [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithMoonsetForDay) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}
EBVM_OP1(moonsetForDayHour12ValueN, timerNumber)
{
    return [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithMoonsetForDay) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}
EBVM_OP0(moonsetForDayHour12ValueAngle)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithMoonsetForDay) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}
EBVM_OP1(moonsetForDayHour12ValueAngleN, timerNumber)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithMoonsetForDay) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}

// 13:45:00 => 13
EBVM_OP0(moonsetForDayHour24Number)
{
    return [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithMoonsetForDay) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}
EBVM_OP1(moonsetForDayHour24NumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithMoonsetForDay) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}
EBVM_OP0(moonsetForDayHour24NumberAngle)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithMoonsetForDay) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}
EBVM_OP1(moonsetForDayHour24NumberAngleN, timerNumber)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithMoonsetForDay) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}

// 13:45:00 => 13.75
EBVM_OP0(moonsetForDayHour24Value)
{
    return [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithMoonsetForDay) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}
EBVM_OP1(moonsetForDayHour24ValueN, timerNumber)
{
    return [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithMoonsetForDay) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}
EBVM_OP0(moonsetForDayHour24ValueAngle)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithMoonsetForDay) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}
EBVM_OP1(moonsetForDayHour24ValueAngleN, timerNumber)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithMoonsetForDay) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}
EBVM_OP0(moonsetForDayValid)
{
    return [[[virtualMachine owner] mainAstro] moonsetForDayValid];
}
EBVM_OP1(moonsetForDayValidN, timerNumber)
{
    return [[[virtualMachine owner] astroWithIndex:timerNumber] moonsetForDayValid];
}

// hook

// 12:35:45 => 35
EBVM_OP0(nextMoonriseMinuteNumber)
{
    return [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithNextMoonrise) watchTimeSelector:@selector(minuteNumberUsingEnv:)];
}
EBVM_OP1(nextMoonriseMinuteNumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextMoonrise) watchTimeSelector:@selector(minuteNumberUsingEnv:)];
}
EBVM_OP0(nextMoonriseMinuteNumberAngle)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithNextMoonrise) watchTimeSelector:@selector(minuteNumberUsingEnv:)];
}
EBVM_OP1(nextMoonriseMinuteNumberAngleN, timerNumber)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextMoonrise) watchTimeSelector:@selector(minuteNumberUsingEnv:)];
}

// 12:35:45 => 35.75
EBVM_OP0(nextMoonriseMinuteValue)
{
    return [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithNextMoonrise) watchTimeSelector:@selector(minuteValueUsingEnv:)];
}
EBVM_OP1(nextMoonriseMinuteValueN, timerNumber)
{
    return [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextMoonrise) watchTimeSelector:@selector(minuteValueUsingEnv:)];
}
EBVM_OP0(nextMoonriseMinuteValueAngle)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithNextMoonrise) watchTimeSelector:@selector(minuteValueUsingEnv:)];
}
EBVM_OP1(nextMoonriseMinuteValueAngleN, timerNumber)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextMoonrise) watchTimeSelector:@selector(minuteValueUsingEnv:)];
}

// 13:45:00 => 1
EBVM_OP0(nextMoonriseHour12Number)
{
    return [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithNextMoonrise) watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}
EBVM_OP1(nextMoonriseHour12NumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextMoonrise) watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}
EBVM_OP0(nextMoonriseHour12NumberAngle)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithNextMoonrise) watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}
EBVM_OP1(nextMoonriseHour12NumberAngleN, timerNumber)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextMoonrise) watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}

// 13:45:00 => 1.75
EBVM_OP0(nextMoonriseHour12Value)
{
    return [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithNextMoonrise) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}
EBVM_OP1(nextMoonriseHour12ValueN, timerNumber)
{
    return [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextMoonrise) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}
EBVM_OP0(nextMoonriseHour12ValueAngle)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithNextMoonrise) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}
EBVM_OP1(nextMoonriseHour12ValueAngleN, timerNumber)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextMoonrise) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}

// 13:45:00 => 13
EBVM_OP0(nextMoonriseHour24Number)
{
    return [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithNextMoonrise) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}
EBVM_OP1(nextMoonriseHour24NumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextMoonrise) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}
EBVM_OP0(nextMoonriseHour24NumberAngle)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithNextMoonrise) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}
EBVM_OP1(nextMoonriseHour24NumberAngleN, timerNumber)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextMoonrise) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}

// 13:45:00 => 13.75
EBVM_OP0(nextMoonriseHour24Value)
{
    return [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithNextMoonrise) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}
EBVM_OP1(nextMoonriseHour24ValueN, timerNumber)
{
    return [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextMoonrise) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}
EBVM_OP0(nextMoonriseHour24ValueAngle)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithNextMoonrise) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}
EBVM_OP1(nextMoonriseHour24ValueAngleN, timerNumber)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextMoonrise) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}
EBVM_OP0(nextMoonriseDayOffset)
{
    return [[virtualMachine owner] getDayOffsetValueFromMainAstroWatchTime:@selector(watchTimeWithNextMoonrise)];
}
EBVM_OP1(nextMoonriseDayOffsetN, timerNumber)
{
    return [[virtualMachine owner] getDayOffsetValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextMoonrise)];
}
EBVM_OP0(nextMoonriseValid)
{
    return [[[virtualMachine owner] mainAstro] nextMoonriseValid];
}
EBVM_OP1(nextMoonriseValidN, timerNumber)
{
    return [[[virtualMachine owner] astroWithIndex:timerNumber] nextMoonriseValid];
}

// 12:35:45 => 35
EBVM_OP0(nextMoonsetMinuteNumber)
{
    return [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithNextMoonset) watchTimeSelector:@selector(minuteNumberUsingEnv:)];
}
EBVM_OP1(nextMoonsetMinuteNumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextMoonset) watchTimeSelector:@selector(minuteNumberUsingEnv:)];
}
EBVM_OP0(nextMoonsetMinuteNumberAngle)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithNextMoonset) watchTimeSelector:@selector(minuteNumberUsingEnv:)];
}
EBVM_OP1(nextMoonsetMinuteNumberAngleN, timerNumber)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextMoonset) watchTimeSelector:@selector(minuteNumberUsingEnv:)];
}

// 12:35:45 => 35.75
EBVM_OP0(nextMoonsetMinuteValue)
{
    return [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithNextMoonset) watchTimeSelector:@selector(minuteValueUsingEnv:)];
}
EBVM_OP1(nextMoonsetMinuteValueN, timerNumber)
{
    return [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextMoonset) watchTimeSelector:@selector(minuteValueUsingEnv:)];
}
EBVM_OP0(nextMoonsetMinuteValueAngle)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithNextMoonset) watchTimeSelector:@selector(minuteValueUsingEnv:)];
}
EBVM_OP1(nextMoonsetMinuteValueAngleN, timerNumber)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextMoonset) watchTimeSelector:@selector(minuteValueUsingEnv:)];
}

// 13:45:00 => 1
EBVM_OP0(nextMoonsetHour12Number)
{
    return [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithNextMoonset) watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}
EBVM_OP1(nextMoonsetHour12NumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextMoonset) watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}
EBVM_OP0(nextMoonsetHour12NumberAngle)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithNextMoonset) watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}
EBVM_OP1(nextMoonsetHour12NumberAngleN, timerNumber)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextMoonset) watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}

// 13:45:00 => 1.75
EBVM_OP0(nextMoonsetHour12Value)
{
    return [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithNextMoonset) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}
EBVM_OP1(nextMoonsetHour12ValueN, timerNumber)
{
    return [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextMoonset) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}
EBVM_OP0(nextMoonsetHour12ValueAngle)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithNextMoonset) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}
EBVM_OP1(nextMoonsetHour12ValueAngleN, timerNumber)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextMoonset) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}

// 13:45:00 => 13
EBVM_OP0(nextMoonsetHour24Number)
{
    return [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithNextMoonset) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}
EBVM_OP1(nextMoonsetHour24NumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextMoonset) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}
EBVM_OP0(nextMoonsetHour24NumberAngle)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithNextMoonset) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}
EBVM_OP1(nextMoonsetHour24NumberAngleN, timerNumber)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextMoonset) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}

// 13:45:00 => 13.75
EBVM_OP0(nextMoonsetHour24Value)
{
    return [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithNextMoonset) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}
EBVM_OP1(nextMoonsetHour24ValueN, timerNumber)
{
    return [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextMoonset) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}
EBVM_OP0(nextMoonsetHour24ValueAngle)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithNextMoonset) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}
EBVM_OP1(nextMoonsetHour24ValueAngleN, timerNumber)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextMoonset) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}
EBVM_OP0(nextMoonsetDayOffset)
{
    return [[virtualMachine owner] getDayOffsetValueFromMainAstroWatchTime:@selector(watchTimeWithNextMoonset)];
}
EBVM_OP1(nextMoonsetDayOffsetN, timerNumber)
{
    return [[virtualMachine owner] getDayOffsetValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithNextMoonset)];
}
EBVM_OP0(nextMoonsetValid)
{
    return [[[virtualMachine owner] mainAstro] nextMoonsetValid];
}
EBVM_OP1(nextMoonsetValidN, timerNumber)
{
    return [[[virtualMachine owner] astroWithIndex:timerNumber] nextMoonsetValid];
}

// 12:35:45 => 35
EBVM_OP0(closestNewMoonMinuteNumber)
{
    return [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithClosestNewMoon) watchTimeSelector:@selector(minuteNumberUsingEnv:)];
}
EBVM_OP1(closestNewMoonMinuteNumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestNewMoon) watchTimeSelector:@selector(minuteNumberUsingEnv:)];
}
EBVM_OP0(closestNewMoonMinuteNumberAngle)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithClosestNewMoon) watchTimeSelector:@selector(minuteNumberUsingEnv:)];
}
EBVM_OP1(closestNewMoonMinuteNumberAngleN, timerNumber)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestNewMoon) watchTimeSelector:@selector(minuteNumberUsingEnv:)];
}

// 12:35:45 => 35.75
EBVM_OP0(closestNewMoonMinuteValue)
{
    return [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithClosestNewMoon) watchTimeSelector:@selector(minuteValueUsingEnv:)];
}
EBVM_OP1(closestNewMoonMinuteValueN, timerNumber)
{
    return [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestNewMoon) watchTimeSelector:@selector(minuteValueUsingEnv:)];
}
EBVM_OP0(closestNewMoonMinuteValueAngle)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithClosestNewMoon) watchTimeSelector:@selector(minuteValueUsingEnv:)];
}
EBVM_OP1(closestNewMoonMinuteValueAngleN, timerNumber)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestNewMoon) watchTimeSelector:@selector(minuteValueUsingEnv:)];
}

// 13:45:00 => 1
EBVM_OP0(closestNewMoonHour12Number)
{
    return [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithClosestNewMoon) watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}
EBVM_OP1(closestNewMoonHour12NumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestNewMoon) watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}
EBVM_OP0(closestNewMoonHour12NumberAngle)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithClosestNewMoon) watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}
EBVM_OP1(closestNewMoonHour12NumberAngleN, timerNumber)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestNewMoon) watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}

// 13:45:00 => 1.75
EBVM_OP0(closestNewMoonHour12Value)
{
    return [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithClosestNewMoon) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}
EBVM_OP1(closestNewMoonHour12ValueN, timerNumber)
{
    return [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestNewMoon) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}
EBVM_OP0(closestNewMoonHour12ValueAngle)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithClosestNewMoon) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}
EBVM_OP1(closestNewMoonHour12ValueAngleN, timerNumber)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestNewMoon) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}

// 13:45:00 => 13
EBVM_OP0(closestNewMoonHour24Number)
{
    return [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithClosestNewMoon) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}
EBVM_OP1(closestNewMoonHour24NumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestNewMoon) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}
EBVM_OP0(closestNewMoonHour24NumberAngle)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithClosestNewMoon) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}
EBVM_OP1(closestNewMoonHour24NumberAngleN, timerNumber)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestNewMoon) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}

// 13:45:00 => 13.75
EBVM_OP0(closestNewMoonHour24Value)
{
    return [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithClosestNewMoon) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}
EBVM_OP1(closestNewMoonHour24ValueN, timerNumber)
{
    return [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestNewMoon) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}
EBVM_OP0(closestNewMoonHour24ValueAngle)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithClosestNewMoon) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}
EBVM_OP1(closestNewMoonHour24ValueAngleN, timerNumber)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestNewMoon) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}
EBVM_OP0(closestNewMoonDayOffset)
{
    return [[virtualMachine owner] getDayOffsetValueFromMainAstroWatchTime:@selector(watchTimeWithClosestNewMoon)];
}
EBVM_OP1(closestNewMoonDayOffsetN, timerNumber)
{
    return [[virtualMachine owner] getDayOffsetValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestNewMoon)];
}
EBVM_OP0(closestNewMoonDayNumber)
{
    return [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithClosestNewMoon) watchTimeSelector:@selector(dayNumberUsingEnv:)];
}
EBVM_OP1(closestNewMoonDayNumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestNewMoon) watchTimeSelector:@selector(dayNumberUsingEnv:)];
}
// Note: dayNumber and dayValue angles are assumed to be for a dial with 31 days
EBVM_OP0(closestNewMoonDayNumberAngle)
{
    return (2 * M_PI / 31) * [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithClosestNewMoon) watchTimeSelector:@selector(dayNumberUsingEnv:)];
}
EBVM_OP1(closestNewMoonDayNumberAngleN, timerNumber)
{
    return (2 * M_PI / 31) * [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestNewMoon) watchTimeSelector:@selector(dayNumberUsingEnv:)];
}


// 12:35:45 => 35
EBVM_OP0(closestFullMoonMinuteNumber)
{
    return [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithClosestFullMoon) watchTimeSelector:@selector(minuteNumberUsingEnv:)];
}
EBVM_OP1(closestFullMoonMinuteNumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestFullMoon) watchTimeSelector:@selector(minuteNumberUsingEnv:)];
}
EBVM_OP0(closestFullMoonMinuteNumberAngle)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithClosestFullMoon) watchTimeSelector:@selector(minuteNumberUsingEnv:)];
}
EBVM_OP1(closestFullMoonMinuteNumberAngleN, timerNumber)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestFullMoon) watchTimeSelector:@selector(minuteNumberUsingEnv:)];
}

// 12:35:45 => 35.75
EBVM_OP0(closestFullMoonMinuteValue)
{
    return [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithClosestFullMoon) watchTimeSelector:@selector(minuteValueUsingEnv:)];
}
EBVM_OP1(closestFullMoonMinuteValueN, timerNumber)
{
    return [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestFullMoon) watchTimeSelector:@selector(minuteValueUsingEnv:)];
}
EBVM_OP0(closestFullMoonMinuteValueAngle)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithClosestFullMoon) watchTimeSelector:@selector(minuteValueUsingEnv:)];
}
EBVM_OP1(closestFullMoonMinuteValueAngleN, timerNumber)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestFullMoon) watchTimeSelector:@selector(minuteValueUsingEnv:)];
}

// 13:45:00 => 1
EBVM_OP0(closestFullMoonHour12Number)
{
    return [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithClosestFullMoon) watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}
EBVM_OP1(closestFullMoonHour12NumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestFullMoon) watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}
EBVM_OP0(closestFullMoonHour12NumberAngle)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithClosestFullMoon) watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}
EBVM_OP1(closestFullMoonHour12NumberAngleN, timerNumber)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestFullMoon) watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}

// 13:45:00 => 1.75
EBVM_OP0(closestFullMoonHour12Value)
{
    return [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithClosestFullMoon) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}
EBVM_OP1(closestFullMoonHour12ValueN, timerNumber)
{
    return [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestFullMoon) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}
EBVM_OP0(closestFullMoonHour12ValueAngle)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithClosestFullMoon) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}
EBVM_OP1(closestFullMoonHour12ValueAngleN, timerNumber)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestFullMoon) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}

// 13:45:00 => 13
EBVM_OP0(closestFullMoonHour24Number)
{
    return [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithClosestFullMoon) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}
EBVM_OP1(closestFullMoonHour24NumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestFullMoon) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}
EBVM_OP0(closestFullMoonHour24NumberAngle)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithClosestFullMoon) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}
EBVM_OP1(closestFullMoonHour24NumberAngleN, timerNumber)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestFullMoon) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}

// 13:45:00 => 13.75
EBVM_OP0(closestFullMoonHour24Value)
{
    return [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithClosestFullMoon) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}
EBVM_OP1(closestFullMoonHour24ValueN, timerNumber)
{
    return [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestFullMoon) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}
EBVM_OP0(closestFullMoonHour24ValueAngle)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithClosestFullMoon) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}
EBVM_OP1(closestFullMoonHour24ValueAngleN, timerNumber)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestFullMoon) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}
EBVM_OP0(closestFullMoonDayOffset)
{
    return [[virtualMachine owner] getDayOffsetValueFromMainAstroWatchTime:@selector(watchTimeWithClosestFullMoon)];
}
EBVM_OP1(closestFullMoonDayOffsetN, timerNumber)
{
    return [[virtualMachine owner] getDayOffsetValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestFullMoon)];
}
EBVM_OP0(closestFullMoonDayNumber)
{
    return [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithClosestFullMoon) watchTimeSelector:@selector(dayNumberUsingEnv:)];
}
EBVM_OP1(closestFullMoonDayNumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestFullMoon) watchTimeSelector:@selector(dayNumberUsingEnv:)];
}
// Note: dayNumber and dayValue angles are assumed to be for a dial with 31 days
EBVM_OP0(closestFullMoonDayNumberAngle)
{
    return (2 * M_PI / 31) * [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithClosestFullMoon) watchTimeSelector:@selector(dayNumberUsingEnv:)];
}
EBVM_OP1(closestFullMoonDayNumberAngleN, timerNumber)
{
    return (2 * M_PI / 31) * [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestFullMoon) watchTimeSelector:@selector(dayNumberUsingEnv:)];
}

// 12:35:45 => 35
EBVM_OP0(closestFirstQuarterMinuteNumber)
{
    return [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithClosestFirstQuarter) watchTimeSelector:@selector(minuteNumberUsingEnv:)];
}
EBVM_OP1(closestFirstQuarterMinuteNumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestFirstQuarter) watchTimeSelector:@selector(minuteNumberUsingEnv:)];
}
EBVM_OP0(closestFirstQuarterMinuteNumberAngle)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithClosestFirstQuarter) watchTimeSelector:@selector(minuteNumberUsingEnv:)];
}
EBVM_OP1(closestFirstQuarterMinuteNumberAngleN, timerNumber)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestFirstQuarter) watchTimeSelector:@selector(minuteNumberUsingEnv:)];
}

// 12:35:45 => 35.75
EBVM_OP0(closestFirstQuarterMinuteValue)
{
    return [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithClosestFirstQuarter) watchTimeSelector:@selector(minuteValueUsingEnv:)];
}
EBVM_OP1(closestFirstQuarterMinuteValueN, timerNumber)
{
    return [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestFirstQuarter) watchTimeSelector:@selector(minuteValueUsingEnv:)];
}
EBVM_OP0(closestFirstQuarterMinuteValueAngle)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithClosestFirstQuarter) watchTimeSelector:@selector(minuteValueUsingEnv:)];
}
EBVM_OP1(closestFirstQuarterMinuteValueAngleN, timerNumber)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestFirstQuarter) watchTimeSelector:@selector(minuteValueUsingEnv:)];
}

// 13:45:00 => 1
EBVM_OP0(closestFirstQuarterHour12Number)
{
    return [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithClosestFirstQuarter) watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}
EBVM_OP1(closestFirstQuarterHour12NumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestFirstQuarter) watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}
EBVM_OP0(closestFirstQuarterHour12NumberAngle)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithClosestFirstQuarter) watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}
EBVM_OP1(closestFirstQuarterHour12NumberAngleN, timerNumber)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestFirstQuarter) watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}

// 13:45:00 => 1.75
EBVM_OP0(closestFirstQuarterHour12Value)
{
    return [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithClosestFirstQuarter) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}
EBVM_OP1(closestFirstQuarterHour12ValueN, timerNumber)
{
    return [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestFirstQuarter) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}
EBVM_OP0(closestFirstQuarterHour12ValueAngle)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithClosestFirstQuarter) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}
EBVM_OP1(closestFirstQuarterHour12ValueAngleN, timerNumber)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestFirstQuarter) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}

// 13:45:00 => 13
EBVM_OP0(closestFirstQuarterHour24Number)
{
    return [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithClosestFirstQuarter) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}
EBVM_OP1(closestFirstQuarterHour24NumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestFirstQuarter) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}
EBVM_OP0(closestFirstQuarterHour24NumberAngle)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithClosestFirstQuarter) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}
EBVM_OP1(closestFirstQuarterHour24NumberAngleN, timerNumber)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestFirstQuarter) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}

// 13:45:00 => 13.75
EBVM_OP0(closestFirstQuarterHour24Value)
{
    return [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithClosestFirstQuarter) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}
EBVM_OP1(closestFirstQuarterHour24ValueN, timerNumber)
{
    return [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestFirstQuarter) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}
EBVM_OP0(closestFirstQuarterHour24ValueAngle)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithClosestFirstQuarter) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}
EBVM_OP1(closestFirstQuarterHour24ValueAngleN, timerNumber)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestFirstQuarter) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}
EBVM_OP0(closestFirstQuarterDayOffset)
{
    return [[virtualMachine owner] getDayOffsetValueFromMainAstroWatchTime:@selector(watchTimeWithClosestFirstQuarter)];
}
EBVM_OP1(closestFirstQuarterDayOffsetN, timerNumber)
{
    return [[virtualMachine owner] getDayOffsetValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestFirstQuarter)];
}
EBVM_OP0(closestFirstQuarterDayNumber)
{
    return [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithClosestFirstQuarter) watchTimeSelector:@selector(dayNumberUsingEnv:)];
}
EBVM_OP1(closestFirstQuarterDayNumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestFirstQuarter) watchTimeSelector:@selector(dayNumberUsingEnv:)];
}
// Note: dayNumber and dayValue angles are assumed to be for a dial with 31 days
EBVM_OP0(closestFirstQuarterDayNumberAngle)
{
    return (2 * M_PI / 31) * [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithClosestFirstQuarter) watchTimeSelector:@selector(dayNumberUsingEnv:)];
}
EBVM_OP1(closestFirstQuarterDayNumberAngleN, timerNumber)
{
    return (2 * M_PI / 31) * [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestFirstQuarter) watchTimeSelector:@selector(dayNumberUsingEnv:)];
}

// 12:35:45 => 35
EBVM_OP0(closestThirdQuarterMinuteNumber)
{
    return [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithClosestThirdQuarter) watchTimeSelector:@selector(minuteNumberUsingEnv:)];
}
EBVM_OP1(closestThirdQuarterMinuteNumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestThirdQuarter) watchTimeSelector:@selector(minuteNumberUsingEnv:)];
}
EBVM_OP0(closestThirdQuarterMinuteNumberAngle)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithClosestThirdQuarter) watchTimeSelector:@selector(minuteNumberUsingEnv:)];
}
EBVM_OP1(closestThirdQuarterMinuteNumberAngleN, timerNumber)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestThirdQuarter) watchTimeSelector:@selector(minuteNumberUsingEnv:)];
}

// 12:35:45 => 35.75
EBVM_OP0(closestThirdQuarterMinuteValue)
{
    return [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithClosestThirdQuarter) watchTimeSelector:@selector(minuteValueUsingEnv:)];
}
EBVM_OP1(closestThirdQuarterMinuteValueN, timerNumber)
{
    return [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestThirdQuarter) watchTimeSelector:@selector(minuteValueUsingEnv:)];
}
EBVM_OP0(closestThirdQuarterMinuteValueAngle)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithClosestThirdQuarter) watchTimeSelector:@selector(minuteValueUsingEnv:)];
}
EBVM_OP1(closestThirdQuarterMinuteValueAngleN, timerNumber)
{
    return (2 * M_PI / 60) * [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestThirdQuarter) watchTimeSelector:@selector(minuteValueUsingEnv:)];
}

// 13:45:00 => 1
EBVM_OP0(closestThirdQuarterHour12Number)
{
    return [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithClosestThirdQuarter) watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}
EBVM_OP1(closestThirdQuarterHour12NumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestThirdQuarter) watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}
EBVM_OP0(closestThirdQuarterHour12NumberAngle)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithClosestThirdQuarter) watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}
EBVM_OP1(closestThirdQuarterHour12NumberAngleN, timerNumber)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestThirdQuarter) watchTimeSelector:@selector(hour12NumberUsingEnv:)];
}

// 13:45:00 => 1.75
EBVM_OP0(closestThirdQuarterHour12Value)
{
    return [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithClosestThirdQuarter) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}
EBVM_OP1(closestThirdQuarterHour12ValueN, timerNumber)
{
    return [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestThirdQuarter) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}
EBVM_OP0(closestThirdQuarterHour12ValueAngle)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithClosestThirdQuarter) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}
EBVM_OP1(closestThirdQuarterHour12ValueAngleN, timerNumber)
{
    return (2 * M_PI / 12) * [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestThirdQuarter) watchTimeSelector:@selector(hour12ValueUsingEnv:)];
}

// 13:45:00 => 13
EBVM_OP0(closestThirdQuarterHour24Number)
{
    return [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithClosestThirdQuarter) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}
EBVM_OP1(closestThirdQuarterHour24NumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestThirdQuarter) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}
EBVM_OP0(closestThirdQuarterHour24NumberAngle)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithClosestThirdQuarter) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}
EBVM_OP1(closestThirdQuarterHour24NumberAngleN, timerNumber)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestThirdQuarter) watchTimeSelector:@selector(hour24NumberUsingEnv:)];
}

// 13:45:00 => 13.75
EBVM_OP0(closestThirdQuarterHour24Value)
{
    return [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithClosestThirdQuarter) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}
EBVM_OP1(closestThirdQuarterHour24ValueN, timerNumber)
{
    return [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestThirdQuarter) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}
EBVM_OP0(closestThirdQuarterHour24ValueAngle)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getValueFromMainAstroWatchTime:@selector(watchTimeWithClosestThirdQuarter) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}
EBVM_OP1(closestThirdQuarterHour24ValueAngleN, timerNumber)
{
    return (2 * M_PI / 24) * [[virtualMachine owner] getValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestThirdQuarter) watchTimeSelector:@selector(hour24ValueUsingEnv:)];
}
EBVM_OP0(closestThirdQuarterDayOffset)
{
    return [[virtualMachine owner] getDayOffsetValueFromMainAstroWatchTime:@selector(watchTimeWithClosestThirdQuarter)];
}
EBVM_OP1(closestThirdQuarterDayOffsetN, timerNumber)
{
    return [[virtualMachine owner] getDayOffsetValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestThirdQuarter)];
}
EBVM_OP0(closestThirdQuarterDayNumber)
{
    return [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithClosestThirdQuarter) watchTimeSelector:@selector(dayNumberUsingEnv:)];
}
EBVM_OP1(closestThirdQuarterDayNumberN, timerNumber)
{
    return [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestThirdQuarter) watchTimeSelector:@selector(dayNumberUsingEnv:)];
}
// Note: dayNumber and dayValue angles are assumed to be for a dial with 31 days
EBVM_OP0(closestThirdQuarterDayNumberAngle)
{
    return (2 * M_PI / 31) * [[virtualMachine owner] getIntValueFromMainAstroWatchTime:@selector(watchTimeWithClosestThirdQuarter) watchTimeSelector:@selector(dayNumberUsingEnv:)];
}
EBVM_OP1(closestThirdQuarterDayNumberAngleN, timerNumber)
{
    return (2 * M_PI / 31) * [[virtualMachine owner] getIntValueFromAstroWatchTimeForEnv:timerNumber astroSelector:@selector(watchTimeWithClosestThirdQuarter) watchTimeSelector:@selector(dayNumberUsingEnv:)];
}

// Return number of days that the day for this time is different from env 0
EBVM_OP1(watchDayOffset, timerNumber)
{
    return [[virtualMachine owner] offsetDaysFromMainForEnv:timerNumber];
}

// Return number of days that the day for this time is different from the other time
EBVM_OP2(watchDayOffsetN, timerNumber, otherTimerNumber)
{
    return [[virtualMachine owner] offsetDaysFrom:otherTimerNumber forEnv:timerNumber];
}

static double makeDate(ESTimeZone *estz, double era, double year, double month, double day, double hour, double minute, double second) {
    ESDateComponents cs;
    cs.era = round(era);
    cs.year = round(year);
    cs.month = round(month);
    cs.day = round(day);
    cs.hour = round(hour);
    cs.minute = round(minute);
    cs.seconds = second;
    return ESCalendar_timeIntervalFromLocalDateComponents(estz, &cs);
}

// Parse a date and return a number suitable for passing to [NSDate dateWithTimeIntervalSinceReferenceDate:xxx]
EBVM_OP7(makeLocalTimeDate, era, year, month, day, hour, minute, second)
{
    return makeDate([[virtualMachine owner] mainEstz], era, year, month, day, hour, minute, second);
}

EBVM_OP7(makeUTDate, era, year, month, day, hour, minute, second)
{
    ESDateComponents cs;
    cs.era = round(era);
    cs.year = round(year);
    cs.month = round(month);
    cs.day = round(day);
    cs.hour = round(hour);
    cs.minute = round(minute);
    cs.seconds = second;
    return ESCalendar_timeIntervalFromUTCDateComponents(&cs);
}

EBVM_OP0(inGridOrOptionMode)
{
    return [ChronometerAppDelegate inGridOrOptionMode];
}

EBVM_OP0(appMode)
{
    if ([ChronometerAppDelegate inSpecialMode]) {
	return specialMask;
    } else {
	switch ([[virtualMachine owner] currentModeNum]) {
	    case ECfrontMode: return frontMask;
	    case ECnightMode: return nightMask;
	    case ECbackMode:  return backMask;
	    default: assert(false); return 0;
	}
    }
}

// Latitude in radians
EBVM_OP0(latitude)
{
    ECLocationManager *locationManager = [[[virtualMachine owner] enviroWithIndex:0] locationManager];
    if ([locationManager valid]) {
	//printAngle([locationManager lastLatitudeRadians], "latitude");
	return [locationManager lastLatitudeRadians];
    } else {
	return 0;
    }
}
EBVM_OP1(latitudeN, timerNumber)
{
    ECLocationManager *locationManager = [[[virtualMachine owner] enviroWithIndex:timerNumber] locationManager];
    if ([locationManager valid]) {
	return [locationManager lastLatitudeRadians];
    } else {
	return 0;
    }
}

// Longitude in radians
EBVM_OP0(longitude)
{
    ECWatchEnvironment *enviro = [[virtualMachine owner] enviroWithIndex:0];
    ECLocationManager *locationManager = [enviro locationManager];
    if ([locationManager valid]) {
	//printAngle([locationManager lastLongitudeRadians], "longitude");
	return [locationManager lastLongitudeRadians];
    } else {
	// Speculative: Return timezone longitude
	// return [[enviro watchTime] tzOffset] * M_PI / (3600 * 12);
	return 0;  // Don't return something that looks right but isn't
    }
}
EBVM_OP1(longitudeN, timerNumber)
{
    ECWatchEnvironment *enviro = [[virtualMachine owner] enviroWithIndex:timerNumber];
    ECLocationManager *locationManager = [enviro locationManager];
    if ([locationManager valid]) {
	return [locationManager lastLongitudeRadians];
    } else {
	// Speculative: Return timezone longitude
	//return [[enviro watchTime] tzOffset] * M_PI / (3600 * 12);
	return 0;  // Don't return something that looks right but isn't
    }
}

// Latitude in degrees
EBVM_OP0(latitudeDegrees)
{
    ECLocationManager *locationManager = [[[virtualMachine owner] enviroWithIndex:0] locationManager];
    if ([locationManager valid]) {
	//printAngle([locationManager lastLatitudeRadians], "latitude");
	return [locationManager lastLatitudeRadians] * 180 / M_PI;
    } else {
	return 0;
    }
}
EBVM_OP1(latitudeDegreesN, timerNumber)
{
    ECLocationManager *locationManager = [[[virtualMachine owner] enviroWithIndex:timerNumber] locationManager];
    if ([locationManager valid]) {
	return [locationManager lastLatitudeRadians] * 180 / M_PI;
    } else {
	return 0;
    }
}

// Longitude in degrees
EBVM_OP0(longitudeDegrees)
{
    ECWatchEnvironment *enviro = [[virtualMachine owner] enviroWithIndex:0];
    ECLocationManager *locationManager = [enviro locationManager];
    if ([locationManager valid]) {
	//printAngle([locationManager lastLongitudeRadians], "longitude");
	return [locationManager lastLongitudeRadians] * 180 / M_PI;
    } else {
	// Speculative: Return timezone longitude
	// return [[enviro watchTime] tzOffset] * 180 / (3600 * 12);
	return 0;  // Don't return something that looks right but isn't
    }
}
EBVM_OP1(longitudeDegreesN, timerNumber)
{
    ECWatchEnvironment *enviro = [[virtualMachine owner] enviroWithIndex:timerNumber];
    ECLocationManager *locationManager = [enviro locationManager];
    if ([locationManager valid]) {
	return [locationManager lastLongitudeRadians] * 180 / M_PI;
    } else {
	// Speculative: Return timezone longitude
	// return [[enviro watchTime] tzOffset] * 180 / (3600 * 12);
	return 0;  // Don't return something that looks right but isn't
    }
}

EBVM_OP0(SIUnits)
{
    ECWatchEnvironment *enviro = [[virtualMachine owner] enviroWithIndex:0];
    ECLocationManager *locationManager = [enviro locationManager];
    return [locationManager SIUnits];
}

EBVM_OP0(toggleSIUnits)
{
    ECWatchEnvironment *enviro = [[virtualMachine owner] enviroWithIndex:0];
    ECLocationManager *locationManager = [enviro locationManager];
    locationManager.SIUnits = ! locationManager.SIUnits;
    return 1;
}

EBVM_OP0(locationIndicatorAngle)
{
    /* indicator wheel color angles:
     green:      0, pi/2
     yellow:     pi, 3*pi/2
     black:      (2*n+1)*pi/4
     */     
    ECWatchEnvironment *enviro = [[virtualMachine owner] enviroWithIndex:0];
    ECLocationManager *locationManager = [enviro locationManager];
    switch ([locationManager indicatorState]) {
	case ECLocGood:		    return M_PI/2;
	case ECLocWorkingGood:	    return ((int)([NSDate timeIntervalSinceReferenceDate]/ECStatusIndicatorBlinkRate) % 2) ? M_PI/2 : M_PI/4;
	case ECLocWorkingUncertain: return ((int)([NSDate timeIntervalSinceReferenceDate]/ECStatusIndicatorBlinkRate) % 2) ? M_PI   : 3*M_PI/4;
	case ECLocUncertain:	    return M_PI;
	case ECLocCanceled:	    return M_PI;
	case ECLocManual:	    return M_PI/4;
	default:		    assert(false);	   return M_PI/4;
    }
}

EBVM_OP0(locationIndicatorColor)
{
    ECWatchEnvironment *enviro = [[virtualMachine owner] enviroWithIndex:0];
    ECLocationManager *locationManager = [enviro locationManager];
    switch ([locationManager indicatorState]) {
	case ECLocGood:		    return ECgreen;
	case ECLocWorkingGood:	    return ((int)([NSDate timeIntervalSinceReferenceDate]/ECStatusIndicatorBlinkRate) % 2) ? ECgreen : ECblack;
	case ECLocWorkingUncertain: return ((int)([NSDate timeIntervalSinceReferenceDate]/ECStatusIndicatorBlinkRate) % 2) ? ECyellow: ECblack;
	case ECLocUncertain:	    return ECyellow;
	case ECLocCanceled:	    return ECyellow;
	case ECLocManual:	    return ECmagenta;
	default:		    assert(false);	   return ECblack;
    }
}

EBVM_OP0(locationManagerActive)
{
    ECWatchEnvironment *enviro = [[virtualMachine owner] enviroWithIndex:0];
    ECLocationManager *locationManager = [enviro locationManager];
    return [locationManager active];
}

EBVM_OP0(locationManagerValid)
{
    ECWatchEnvironment *enviro = [[virtualMachine owner] enviroWithIndex:0];
    ECLocationManager *locationManager = [enviro locationManager];
    return [locationManager valid];
}

EBVM_OP0(requestOneLocationFix)
{
    // probably should:  assert(false);
    ECWatchEnvironment *enviro = [[virtualMachine owner] enviroWithIndex:0];
    ECLocationManager *locationManager = [enviro locationManager];
    [locationManager requestOneLocationFix];		// does not update userDefaults and hence ECOptionsLoc's switch
    return 1;
}

EBVM_OP0(requestLocationUpdates)
{
    ECWatchEnvironment *enviro = [[virtualMachine owner] enviroWithIndex:0];
    ECLocationManager *locationManager = [enviro locationManager];
    [locationManager requestLocationUpdates];
    return 1;
}

EBVM_OP0(stopLocationManager)
{
    ECWatchEnvironment *enviro = [[virtualMachine owner] enviroWithIndex:0];
    ECLocationManager *locationManager = [enviro locationManager];
    [locationManager cancelLocationRequest];
    return 1;
}

EBVM_OP0(goodAccuracy)
{
    ECWatchEnvironment *enviro = [[virtualMachine owner] enviroWithIndex:0];
    ECLocationManager *locationManager = [enviro locationManager];
    return [locationManager accuracyIsGood];
}

EBVM_OP0(horizontalPositionError)
{
    ECWatchEnvironment *enviro = [[virtualMachine owner] enviroWithIndex:0];
    ECLocationManager *locationManager = [enviro locationManager];
    return [locationManager lastHorizontalErrorMeters];
}

EBVM_OP0(logHorizontalPositionError)
{
    ECWatchEnvironment *enviro = [[virtualMachine owner] enviroWithIndex:0];
    ECLocationManager *locationManager = [enviro locationManager];
    double val = [locationManager lastHorizontalErrorMeters];
    if (val <= 0) {
	return 3.5;
    }
    return log10(val);
}

EBVM_OP0(verticalPositionError)
{
    ECWatchEnvironment *enviro = [[virtualMachine owner] enviroWithIndex:0];
    ECLocationManager *locationManager = [enviro locationManager];
    double val = [locationManager lastVerticalErrorMeters];
    if (val <= 0) {
	return 3.5;
    }
    return log10(val);
}

// Altitude (in meters or feet per SIUnits setting)
EBVM_OP0(altitude)
{
    double ret;
    ECWatchEnvironment *enviro = [[virtualMachine owner] enviroWithIndex:0];
    ECLocationManager *locationManager = [enviro locationManager];
    if ([locationManager valid]) {
	//printAngle([locationManager lastAltitudeMeters], "altitude");
	ret = [locationManager lastAltitudeLocalUnits];
    } else {
	ret = -1;
    }
    return ret;
}
EBVM_OP1(altitudeN, timerNumber)
{
    ECWatchEnvironment *enviro = [[virtualMachine owner] enviroWithIndex:timerNumber];
    ECLocationManager *locationManager = [enviro locationManager];
    if ([locationManager valid]) {
	//printAngle([locationManager lastAltitudeMeters], "altitude");
	return [locationManager lastAltitudeMeters];
    } else {
	return -1;
    }
}

EBVM_OP0(locationUpdateCount)
{
    return [ECLocationManager theLocationManager].count;
}

// move north by N degrees
EBVM_OP1(goNorth, dist)
{
    ECLocationManager *locationManager = [[[virtualMachine owner] enviroWithIndex:0] locationManager];
    if ([locationManager valid]) {
	double lat = [locationManager lastLatitudeDegrees];
	lat = lat + dist;
	if (lat > 90) {
	    lat = 90;
	} else if (lat < -90) {
	    lat = -90;
	}
	[locationManager setOverrideLocationToLatitudeDegrees:lat longitudeDegrees:[locationManager lastLongitudeDegrees] altitudeMeters:[locationManager lastAltitudeMeters]];
    }
    return 0;
}

// move east by N degrees
EBVM_OP1(goEast, dist)
{
    ECLocationManager *locationManager = [[[virtualMachine owner] enviroWithIndex:0] locationManager];
    if ([locationManager valid]) {
	double lng = [locationManager lastLongitudeDegrees];
	lng = lng + dist;
	lng = round(lng*3600)/3600;
	if (lng > 180) {
	    lng = lng - 360;
	} else if (lng < -180) {
	    lng = lng + 360;
	}
	[locationManager setOverrideLocationToLatitudeDegrees:[locationManager lastLatitudeDegrees] longitudeDegrees:lng altitudeMeters:[locationManager lastAltitudeMeters]];
    }
    return 0;
}

// Return the value for a digit wheel displaying a given position digitMultiplier (1, 10, 100) and a given precision for rounding (.01, 1/60)
//  139.999, 10, .01 => 4
EBVM_OP3(digitValue, value, digitMultiplier, roundingPrecision)
{
    double precisionUnits = round(value / roundingPrecision);  // round(13999.9) => 14000
    double roundedValue = precisionUnits * roundingPrecision;  // 140.00
    double digitValue = floor(roundedValue / digitMultiplier); // 14  -- caller will have to fmod by number of digits in wheel or hand dial
    // printf("digitValue(%.6f, %.6f, %.6f) => pU %.6f => rV %.6f => %.6f\n", value, digitMultiplier, roundingPrecision, precisionUnits, roundedValue, digitValue);
    return digitValue;
}

EBVM_OP1(isDST, slot)
{
    return [[virtualMachine owner] getBoolValueFromTimeForEnv:slot watchTimeSelector:@selector(isDSTUsingEnv:)] ? 1 : 0;
}

// Only valid iff day0 and dayZ are close together (otherwise the day could be the same on different months, for example)
EBVM_OP2(sameDay, slot, topSlot)
{
    double day0 = [[virtualMachine owner] getIntValueFromTimeForEnv:topSlot watchTimeSelector:@selector(dayNumberUsingEnv:)];
    double dayZ = [[virtualMachine owner] getIntValueFromTimeForEnv:slot    watchTimeSelector:@selector(dayNumberUsingEnv:)];
    return dayZ == day0;
}

// Only valid iff day0 and dayZ are less than 5 days apart
EBVM_OP2(lessDay, slot, topSlot)
{
    double day0 = [[virtualMachine owner] getIntValueFromTimeForEnv:topSlot watchTimeSelector:@selector(dayNumberUsingEnv:)];
    double dayZ = [[virtualMachine owner] getIntValueFromTimeForEnv:slot    watchTimeSelector:@selector(dayNumberUsingEnv:)];
    bool ret = dayZ == day0 - 1 || dayZ > day0 + 5;
    //printf("day0 = %.0f, dayZ = %.0f, lessDay = %s\n", day0, dayZ, ret ? "true" : "false");
    return ret;
}

// Only valid iff day0 and dayZ are less than 5 days apart
EBVM_OP2(moreDay, slot, topSlot)
{
    double day0 = [[virtualMachine owner] getIntValueFromTimeForEnv:topSlot watchTimeSelector:@selector(dayNumberUsingEnv:)];
    double dayZ = [[virtualMachine owner] getIntValueFromTimeForEnv:slot    watchTimeSelector:@selector(dayNumberUsingEnv:)];
    bool ret = day0 == dayZ - 1 || day0 > dayZ + 5;
    //printf("day0 = %.0f, dayZ = %.0f, moreDay = %s\n", day0, dayZ, ret ? "true" : "false");
    return ret;
}

EBVM_OP2(sectorAngle, slot, topSlot)
{
    return (slot - topSlot) * M_PI/12;
}

EBVM_OP0(terraIDeviceSlot)
{
    printf("terraIDeviceSlot is a no-op in CwHA\n");
    return 0;
}

EBVM_OP1(overrideTerraITopSlot, tempTopRingSlot)
{
    printf("overrideTerraITopSlot is a no-op in CwHA\n");
    return 0;
}

// The number of sectors offset from firstSlot's angle that GMT/UTC appears (is 10.5 currently)
EBVM_OP0(UTCSectorOffset)
{
    return [ECFactoryUI UTCSectorOffset];
}

#undef EC_OFFSET_CITY_INDICATOR  // Should the city indicator on Terra be offset from the top of the watch so that the local time on the 24-hr dial is always at the top
EBVM_OP2(cityIndicatorOffset, topRingSlot, firstRingSlot)
{
#ifdef EC_OFFSET_CITY_INDICATOR
    ECGLWatch *watch = [virtualMachine owner];
    double tzOffsetAngle = [watch getValueFromTimeForEnv:topRingSlot watchTimeSelector:@selector(tzOffsetUsingEnv:)] * M_PI / (3600 * 12);
    double utOffsetAngle = (firstRingSlot - topRingSlot + [ECFactoryUI UTCSectorOffset]) * M_PI/12;
    //printAngle(tzOffsetAngle + utOffsetAngle, "topDotOffset");
    return tzOffsetAngle + utOffsetAngle;
#else
    return 0;
#endif
}
EBVM_OP2(city24HrDialOffset, topRingSlot, firstRingSlot)
{
#ifdef EC_OFFSET_CITY_INDICATOR
    return 0;
#else
    ECGLWatch *watch = [virtualMachine owner];
    double tzOffsetAngle = [watch getValueFromTimeForEnv:topRingSlot watchTimeSelector:@selector(tzOffsetUsingEnv:)] * M_PI / (3600 * 12);
    double utOffsetAngle = (firstRingSlot - topRingSlot + [ECFactoryUI UTCSectorOffset]) * M_PI/12;
    //printAngle(tzOffsetAngle + utOffsetAngle, "topDotOffset");
    return tzOffsetAngle + utOffsetAngle;
#endif
}

EBVM_OP0(tzOffset)
{
    return [[virtualMachine owner] getValueFromMainTime:@selector(tzOffsetUsingEnv:)];
}

// Offset from GMT in radians
EBVM_OP0(tzOffsetAngle)
{
    return [[virtualMachine owner] getValueFromMainTime:@selector(tzOffsetUsingEnv:)] * M_PI / (3600 * 12);
}
EBVM_OP1(tzOffsetAngleN, timerNumber)
{
    return [[virtualMachine owner] getValueFromTimeForEnv:timerNumber watchTimeSelector:@selector(tzOffsetUsingEnv:)] * M_PI / (3600 * 12);
}

// Actions
EBVM_OP2(storePersistentValue, n, val)
{
    [[NSUserDefaults standardUserDefaults] setDouble:val forKey:[NSString stringWithFormat:@"%@-VMVariable-%d",[[virtualMachine owner] name], (int)n]];
    return 0;
}

EBVM_OP1(fetchPersistentValue, n)
{
    return[[NSUserDefaults standardUserDefaults] doubleForKey:[NSString stringWithFormat:@"%@-VMVariable-%d", [[virtualMachine owner] name], (int)n]];
}

EBVM_OP0(stemIn)
{
    [[virtualMachine owner] stemIn];
    return 0;
}

EBVM_OP0(stemOut)
{
    [[virtualMachine owner] stemOut];
    return 0;
}

EBVM_OP0(alarmStemIn)
{
    [[virtualMachine owner] alarmStemIn];
    return 0;
}

EBVM_OP0(alarmStemOut)
{
    [[virtualMachine owner] alarmStemOut];
    return 0;
}

EBVM_OP0(goForward)
{
    [[virtualMachine owner] setRunningBackward:false];
    return 0;
}

EBVM_OP0(goBackward)
{
    [[virtualMachine owner] setRunningBackward:true];
    return 0;
}

EBVM_OP0(reset)
{
    [[virtualMachine owner] resetTime];
    return 0;
}

EBVM_OP0(manualSet)
{
    return ([[virtualMachine owner] manualSet] ? 1.0 : 0.0);
}

EBVM_OP0(alarmManualSet)
{
    return ([[virtualMachine owner] alarmManualSet] ? 1.0 : 0.0);
}

EBVM_OP0(thisButtonPressed)
{
    return ([ChronometerAppDelegate thisButtonPressed] ? 1.0 : 0.0);
}

EBVM_OP0(inReverse)
{
    return ([[virtualMachine owner] runningBackward]);
}

EBVM_OP0(timeIsCorrect)
{
    return ([[[virtualMachine owner] mainTime] isCorrect]);
}

EBVM_OP0(leapYear)
{
    return (double)([[virtualMachine owner] getBoolValueFromMainTime:@selector(leapYearUsingEnv:)]);
}

EBVM_OP0(GregorianEra)
{
    return [[[virtualMachine owner] mainTime] currentTime] > ECGregorianStartDate;
}

EBVM_OP0(leapYearIndicatorAngle)
{
    ECGLWatch *owner = [virtualMachine owner];
    int yearNumber = [owner getIntValueFromMainTime:@selector(yearNumberUsingEnv:)];
    int eraNumber = [owner getIntValueFromMainTime:@selector(eraNumberUsingEnv:)];
    if (eraNumber && yearNumber >= 1582) { // Gregorian
	return M_PI+ (yearNumber % 400 == 0 ? 3*M_PI/4 : yearNumber % 100 == 0 ? 5*M_PI/4 : yearNumber%4 == 0 ? M_PI/4 : ((yearNumber%4)*2+17)*M_PI/12);
    } else { 
	if (eraNumber) { // Julian
	    return M_PI + (yearNumber%4 == 0 ? M_PI/4 : ((yearNumber%4)*2+17)*M_PI/12);
	} else { // proleptic Julian
	    yearNumber -= 1;
	    return M_PI + (yearNumber%4 == 0 ? M_PI/4 : ((yearNumber%4)*2+17)*M_PI/12);
	}
    }
}
EBVM_OP0(leapYearIndicatorAngle1)
{
    ECGLWatch *owner = [virtualMachine owner];
    int yearNumber = [owner getIntValueFromMainTime:@selector(yearNumberUsingEnv:)];
    int eraNumber = [owner getIntValueFromMainTime:@selector(eraNumberUsingEnv:)];
    if (eraNumber && yearNumber >= 1582) { // Gregorian
	return yearNumber%4 != 0 ? M_PI/8 : (yearNumber % 400 == 0 ? -M_PI*3/8 : (yearNumber % 100 == 0 ? M_PI*3/8 : -M_PI/8));
    } else { 
	if (eraNumber) { // Julian
	    return yearNumber%4 != 0 ? M_PI/8 : -M_PI/8;
	} else { // proleptic Julian
	    yearNumber -= 1;
	    return yearNumber%4 != 0 ? M_PI/8 : -M_PI/8;
	}
    }
}

EBVM_OP0(summer)
{
    return (double)([[[virtualMachine owner] mainAstro] summer]);
}

EBVM_OP1(planetSummer, planetNumber)
{
    return (double)([[[virtualMachine owner] mainAstro] planetIsSummer:planetNumber]);
}

EBVM_OP4(dayNightLeafAngle, planetNumber, leafNumber, numLeaves, timeBaseKind)
{
    return (double)([[[virtualMachine owner] mainAstro] dayNightLeafAngleForPlanetNumber:planetNumber
									      leafNumber:leafNumber
									       numLeaves:numLeaves
                                                                            timeBaseKind:timeBaseKind]);
}

EBVM_OP5(dayNightLeafAngleN, planetNumber, leafNumber, numLeaves, timeBaseKind, envSlot)
{
    return (double)([[[virtualMachine owner] astroWithIndex:envSlot] dayNightLeafAngleForPlanetNumber:planetNumber
											   leafNumber:leafNumber
											    numLeaves:numLeaves
                                                                                         timeBaseKind:timeBaseKind]);
}

EBVM_OP1(advanceSeconds, n)
{
    id watchController = [virtualMachine owner];
    if (![watchController runningBackward]) {
	[watchController advanceMainTimeUsingSelector:@selector(advanceBySeconds:) withDoubleParameter:n];
    } else {
	[watchController advanceMainTimeUsingSelector:@selector(advanceBySeconds:) withDoubleParameter:-n];
    }
    return 0;
}

EBVM_OP0(advanceSecond)
{
    id watchController = [virtualMachine owner];
    if (![watchController runningBackward]) {
	[watchController advanceMainTimeUsingSelector:@selector(advanceBySeconds:) withDoubleParameter:1];
    } else {
	[watchController advanceMainTimeUsingSelector:@selector(advanceBySeconds:) withDoubleParameter:-1];
    }
    return 0;
}

EBVM_OP0(advanceMinute)
{
    id watchController = [virtualMachine owner];
    if (![watchController runningBackward]) {
	[watchController advanceMainTimeUsingSelector:@selector(advanceBySeconds:) withDoubleParameter:60];
    } else {
	[watchController advanceMainTimeUsingSelector:@selector(advanceBySeconds:) withDoubleParameter:-60];
    }
    return 0;
}

EBVM_OP0(advanceHour)
{
    id watchController = [virtualMachine owner];
    if (![watchController runningBackward]) {
	[watchController advanceMainTimeUsingSelector:@selector(advanceBySeconds:) withDoubleParameter:3600];
    } else {
	[watchController advanceMainTimeUsingSelector:@selector(advanceBySeconds:) withDoubleParameter:-3600];
    }
    return 0;
}

EBVM_OP0(advanceDay)
{
    id watchController = [virtualMachine owner];
    if (![watchController runningBackward]) {
	[watchController advanceMainTimeUsingEnvSelector:@selector(advanceOneDayUsingEnv:)];
    } else {
	[watchController advanceMainTimeUsingEnvSelector:@selector(retardOneDayUsingEnv:)];
    }
    return 0;
}

EBVM_OP1(advanceDayN, timerNumber)
{
    id watchController = [virtualMachine owner];
    if (![watchController runningBackward]) {
	[watchController advanceTimeForEnvUsingEnvSelector:@selector(advanceOneDayUsingEnv:) forEnv:timerNumber];
    } else {
	[watchController advanceTimeForEnvUsingEnvSelector:@selector(retardOneDayUsingEnv:) forEnv:timerNumber];
    }
    return 0;
}

EBVM_OP1(advanceDays, n)
{
    id watchController = [virtualMachine owner];
    if (![watchController runningBackward]) {
	[watchController advanceMainTimeUsingEnvSelector:@selector(advanceByDays:usingEnv:) withIntParameter:(int)round(n)];
    } else {
	[watchController advanceMainTimeUsingEnvSelector:@selector(advanceByDays:usingEnv:) withIntParameter:(int)round(-n)];
    }
    return 0;
}

EBVM_OP0(advanceMonth)
{
    id watchController = [virtualMachine owner];
    if (![watchController runningBackward]) {
	[watchController advanceMainTimeUsingEnvSelector:@selector(advanceOneMonthUsingEnv:)];
    } else {
	[watchController advanceMainTimeUsingEnvSelector:@selector(retardOneMonthUsingEnv:)];
    }
    return 0;
}

EBVM_OP1(advanceMonthN, timerNumber)
{
    id watchController = [virtualMachine owner];
    if (![watchController runningBackward]) {
	[watchController advanceTimeForEnvUsingEnvSelector:@selector(advanceOneMonthUsingEnv:) forEnv:timerNumber];
    } else {
	[watchController advanceTimeForEnvUsingEnvSelector:@selector(retardOneMonthUsingEnv:) forEnv:timerNumber];
    }
    return 0;
}

EBVM_OP0(advanceYear)
{
    id watchController = [virtualMachine owner];
    if (![watchController runningBackward]) {
	[watchController advanceMainTimeUsingEnvSelector:@selector(advanceOneYearUsingEnv:)];
    } else {
	[watchController advanceMainTimeUsingEnvSelector:@selector(retardOneYearUsingEnv:)];
    }
    return 0;
}

EBVM_OP1(advanceYearN, timerNumber)
{
    id watchController = [virtualMachine owner];
    if (![watchController runningBackward]) {
	[watchController advanceTimeForEnvUsingEnvSelector:@selector(advanceOneYearUsingEnv:) forEnv:timerNumber];
    } else {
	[watchController advanceTimeForEnvUsingEnvSelector:@selector(retardOneYearUsingEnv:) forEnv:timerNumber];
    }
    return 0;
}

EBVM_OP1(advanceYears, n)
{
    id watchController = [virtualMachine owner];
    if (![watchController runningBackward]) {
	[watchController advanceMainTimeUsingEnvSelector:@selector(advanceByYears:usingEnv:) withIntParameter:(int)round(n)];
    } else {
	[watchController advanceMainTimeUsingEnvSelector:@selector(advanceByYears:usingEnv:) withIntParameter:(int)round(-n)];
    }
    return 0;
}

EBVM_OP0(advanceToQuarterHour)
{
    id watchController = [virtualMachine owner];
    if (![watchController runningBackward]) {
	[watchController advanceMainTimeUsingEnvSelector:@selector(advanceToQuarterHourUsingEnv:)];
    } else {
	[watchController advanceMainTimeUsingEnvSelector:@selector(retreatToQuarterHourUsingEnv:)];
    }
    return 0;
}

static void advanceToRiseOfPlanetForDay(EBVirtualMachine *virtualMachine,
					int              planetNumber)
{
    id watchController = [virtualMachine owner];
    ECAstronomyManager *astroMan = [watchController mainAstro];
    NSTimeInterval showing = [astroMan planetriseForDay:planetNumber];
    if (isnan(showing) || fabs([[watchController mainTime] currentTime] - showing) < 0.5) {
	// go to next day (prev if running backward)
	NSTimeInterval nextEvent = [astroMan nextPlanetriseForPlanetNumber:planetNumber];
	if (!isnan(nextEvent)) {
	    [watchController setMainTimeToFrozenDateInterval:nextEvent];
	}
    } else {
	// advance to dial value
	assert(!isnan(showing));  // We just tested for this
	[watchController setMainTimeToFrozenDateInterval:showing];
    }
}

static void advanceToSetOfPlanetForDay(EBVirtualMachine *virtualMachine,
				       int              planetNumber)
{
    id watchController = [virtualMachine owner];
    ECAstronomyManager *astroMan = [watchController mainAstro];
    NSTimeInterval showing = [astroMan planetsetForDay:planetNumber];
    if (isnan(showing) || fabs([[watchController mainTime] currentTime] - showing) < 0.5) {
	// go to next day (prev if running backward)
	NSTimeInterval nextEvent = [astroMan nextPlanetsetForPlanetNumber:planetNumber];
	if (!isnan(nextEvent)) {
	    [watchController setMainTimeToFrozenDateInterval:nextEvent];
	}
    } else {
	// advance to dial value
	assert(!isnan(showing));  // We just tested for this
	[watchController setMainTimeToFrozenDateInterval:showing];
    }
}

EBVM_OP0(advanceToSunriseForDay)
{
    advanceToRiseOfPlanetForDay(virtualMachine, ECPlanetSun);
    return 0;
}

EBVM_OP0(advanceToSunsetForDay)
{
    advanceToSetOfPlanetForDay(virtualMachine, ECPlanetSun);
    return 0;
}

EBVM_OP0(advanceToMoonriseForDay)
{
    advanceToRiseOfPlanetForDay(virtualMachine, ECPlanetMoon);
    return 0;
}

EBVM_OP0(advanceToMoonsetForDay)
{
    advanceToSetOfPlanetForDay(virtualMachine, ECPlanetMoon);
    return 0;
}

EBVM_OP1(advanceToRiseOfPlanetForDay, planetNumber)
{
    advanceToRiseOfPlanetForDay(virtualMachine, planetNumber);
    return 0;
}

EBVM_OP1(advanceToSetOfPlanetForDay, planetNumber)
{
    advanceToSetOfPlanetForDay(virtualMachine, planetNumber);
    return 0;
}

EBVM_OP1(advanceToTransitOfPlanetForDay, planetNumber)
{
    id watchController = [virtualMachine owner];
    ECAstronomyManager *astroMan = [watchController mainAstro];
    NSTimeInterval showing = [astroMan planettransitForDay:planetNumber];
    if (isnan(showing) || fabs([[watchController mainTime] currentTime] - showing) < 0.5) {
	// go to next day (prev if running backward)
	NSTimeInterval nextEvent = [astroMan nextPlanettransit:planetNumber];
	if (!isnan(nextEvent)) {
	    [watchController setMainTimeToFrozenDateInterval:nextEvent];
	}
    } else {
	// advance to dial value
	assert(!isnan(showing));  // We just tested for this
	[watchController setMainTimeToFrozenDateInterval:showing];
    }
    return 0;
}

EBVM_OP0(advanceToNextMoonPhase)
{
    id watchController = [virtualMachine owner];
    [watchController setMainTimeToFrozenDateInterval:[[watchController mainAstro] nextMoonPhase]];
    return 0;
}

EBVM_OP0(advanceToClosestNewMoon)
{
    id watchController = [virtualMachine owner];
    ECAstronomyManager *astroMan = [watchController mainAstro];
    ECGLWatch *theWatch = watchController;
    NSTimeInterval closestTime = [astroMan closestNewMoon];
    double delta = fabs([theWatch currentMainTime] - closestTime);
    if (delta < 2.0) {
	// showing current new moon, go to next one
	[theWatch setMainTimeToFrozenDateInterval:[astroMan nextNewMoon]];
    } else {
	// go to current value
	[theWatch setMainTimeToFrozenDateInterval:closestTime];
    }
    return 0;
}

EBVM_OP0(advanceToClosestFullMoon)
{
    id watchController = [virtualMachine owner];
    ECAstronomyManager *astroMan = [watchController mainAstro];
    ECGLWatch *theWatch = watchController;
    NSTimeInterval closestTime = [astroMan closestFullMoon];
    double delta = fabs([theWatch currentMainTime] - closestTime);
    if (delta < 2.0) {
	// showing current full moon, go to next one
	[theWatch setMainTimeToFrozenDateInterval:[astroMan nextFullMoon]];
    } else {
	// go to current value
	[theWatch setMainTimeToFrozenDateInterval:closestTime];
    }
    return 0;
}

EBVM_OP0(advanceToClosestFirstQuarter)
{
    id watchController = [virtualMachine owner];
    ECAstronomyManager *astroMan = [watchController mainAstro];
    ECGLWatch *theWatch = watchController;
    NSTimeInterval closestTime = [astroMan closestFirstQuarter];
    double delta = fabs([theWatch currentMainTime] - closestTime);
    if (delta < 2.0) {
	// showing current full moon, go to next one
	[theWatch setMainTimeToFrozenDateInterval:[astroMan nextFirstQuarter]];
    } else {
	// go to current value
	[theWatch setMainTimeToFrozenDateInterval:closestTime];
    }
    return 0;
}

EBVM_OP0(advanceToClosestThirdQuarter)
{
    id watchController = [virtualMachine owner];
    ECAstronomyManager *astroMan = [watchController mainAstro];
    ECGLWatch *theWatch = watchController;
    NSTimeInterval closestTime = [astroMan closestThirdQuarter];
    double delta = fabs([theWatch currentMainTime] - closestTime);
    if (delta < 2.0) {
	// showing current full moon, go to next one
	[theWatch setMainTimeToFrozenDateInterval:[astroMan nextThirdQuarter]];
    } else {
	// go to current value
	[theWatch setMainTimeToFrozenDateInterval:closestTime];
    }
    return 0;
}

EBVM_OP1(centerOfZodiacConstellation, n)
{
    return [ECAstronomyManager centerOfZodiacConstellation:n];
}

EBVM_OP1(widthOfZodiacConstellation, n)
{
    return [ECAstronomyManager widthOfZodiacConstellation:n];
}

EBVM_OP0(advanceAlarmHour)
{
    id watchController = [virtualMachine owner];
    [watchController advanceAlarmHour];
    return 0;
}

EBVM_OP0(advanceAlarmMinute)
{
    id watchController = [virtualMachine owner];
    [watchController advanceAlarmMinute];
    return 0;
}

EBVM_OP0(toggleAlarmAMPM)
{
    id watchController = [virtualMachine owner];
    [watchController toggleAlarmAMPM];
    return 0;
}

EBVM_OP0(advanceIntervalHour)
{
    id watchController = [virtualMachine owner];
    [watchController advanceIntervalHour];
    return 0;
}

EBVM_OP0(advanceIntervalMinute)
{
    id watchController = [virtualMachine owner];
    [watchController advanceIntervalMinute];
    return 0;
}

EBVM_OP0(advanceIntervalSecond)
{
    id watchController = [virtualMachine owner];
    [watchController advanceIntervalSecond];
    return 0;
}

EBVM_OP0(switchToNextActiveAlarmWatch)
{
    return [ChronometerAppDelegate switchToNextActiveAlarmWatch];
}

EBVM_OP0(alarmCount)
{
    id watchController = [virtualMachine owner];
    return [watchController alarmCount];
}

EBVM_OP0(enableAlarm)
{
    id watchController = [virtualMachine owner];
    [watchController enableAlarm];
    return 0;
}

EBVM_OP0(disableAlarm)
{
    id watchController = [virtualMachine owner];
    [watchController disableAlarm];
    return 0;
}

EBVM_OP0(startIntervalTimer)
{
    id watchController = [virtualMachine owner];
    [watchController startIntervalTimer];
    return 0;
}

EBVM_OP0(stopIntervalTimer)
{
    id watchController = [virtualMachine owner];
    [watchController stopIntervalTimer];
    return 0;
}

EBVM_OP0(toggleIntervalTimer)
{
    id watchController = [virtualMachine owner];
    [watchController toggleIntervalTimer];
    return 0;
}

EBVM_OP0(alarmEnabled)
{
    id watchController = [virtualMachine owner];
    return [watchController alarmEnabled];
}

EBVM_OP0(alarmRinging)
{
    return [ECAudio ringing];
}

EBVM_OP0(rings)
{
    return [ECAudio ringCount];
}

EBVM_OP0(alarmTypeTarget)
{
    id watchController = [virtualMachine owner];
    [watchController setAlarmToTarget];
    return 0;
}

EBVM_OP0(alarmTypeInterval)
{
    id watchController = [virtualMachine owner];
    [watchController setAlarmToInterval];
    return 0;
}

EBVM_OP0(alarmIsZero)
{
    double currentTime = [[[virtualMachine owner] intervalTimer] currentTime];
    double returnValue = fabs(currentTime) < 0.01 || fabs(currentTime - 86400) < 0.01;
    return returnValue;
}

EBVM_OP0(alarmReset)
{
    [[virtualMachine owner] alarmReset];
    return 0;
}

EBVM_OP0(runDemo)
{
#ifdef FIXFIXFIX
    id watchController = [virtualMachine owner];
    [watchController runDemo];
#endif
    return 0;
}

EBVM_OP0(cancelDemo)
{
#ifdef FIXFIXFIX
    id watchController = [virtualMachine owner];
    [watchController cancelDemo];
#endif
    return 0;
}

EBVM_OP0(runningDemo)
{
#ifdef FIXFIXFIX
    return [ECWatchController runningDemo];  // won't work without Henry
#endif
    return false;
}

EBVM_OP1(dataFlip, which)
{
    [ChronometerAppDelegate dataFlip:which];
    return 0;
}

EBVM_OP0(backFlip)
{
    [ChronometerAppDelegate backFlip];
    return 0;
}

EBVM_OP0(nightFlip)
{
    [ChronometerAppDelegate nightFlip];
    return 0;
}

EBVM_OP0(dayFlip)
{
    [ChronometerAppDelegate dayFlip];
    return 0;
}

EBVM_OP0(info)
{
    [ChronometerAppDelegate infoFlip];
    return 0;
}

EBVM_OP0(option)
{
    [ChronometerAppDelegate optionFlip];
    return 0;
}

EBVM_OP0(grid)
{
    [ChronometerAppDelegate gridFlip];
    return 0;
}

EBVM_OP0(watchSelector)
{
    [ChronometerAppDelegate selectorFlip];
    return 0;
}

// The following two functions are duplicates of methods in ECQView.m

// The phase angle for which the inner terminator edge shape is correct for this leaf
// Index numbers always start on the outside and work inward
static double
phaseAngleForInnerTerminatorEdgeForcingLowerRight(bool                 forceLowerRight,
						  ECTerminatorQuadrant quadrant,
						  int                  indexWithinQuadrant,
						  int                  leavesPerQuadrant) {
    if (!forceLowerRight && ECTerminatorQuadrantIsLeft(quadrant)) { // left side, terminator decreasing from pi back to pi/2
	// First terminator will not be at pi, but last terminator *must* be at pi/2 to make quarter moon exact
	return M_PI - ((indexWithinQuadrant + 1.0) / leavesPerQuadrant) * (M_PI / 2);
    } else { // right side, terminator increasing from pi to 3pi/2
	// First terminator will not be at pi, but last terminator *must* be at 3pi/2 to make quarter moon exact
	return M_PI + ((indexWithinQuadrant + 1.0) / leavesPerQuadrant) * (M_PI / 2);
    }
}

// The phase angle for which the outer terminator edge shape is correct for this leaf
// Index numbers always start on the outside and work inward
static double
phaseAngleForOuterTerminatorEdgeForcingLowerRight(bool                 forceLowerRight,
						  ECTerminatorQuadrant quadrant,
						  int                  indexWithinQuadrant,
						  int                  leavesPerQuadrant) {
    if (!forceLowerRight && ECTerminatorQuadrantIsLeft(quadrant)) { // left side, terminator decreasing from 2pi back to 3pi/2
	// First terminator should be exact so new moon looks good
	return 2*M_PI - ((double)indexWithinQuadrant / leavesPerQuadrant) * (M_PI / 2);
    } else { // right side, terminator increasing from 0 to pi/2
	// First terminator should be exact so new moon looks good
	return 0      + ((double)indexWithinQuadrant / leavesPerQuadrant) * (M_PI / 2);
    }
}

EBVM_OP5(terminatorAngle, phase, quad, indexWithinQuad, leavesPerQuad, incr)
{
    int quadrant = (int)quad;
    int indexWithinQuadrant = (int)indexWithinQuad;
    int leavesPerQuadrant = (int)leavesPerQuad;
    int incremental = (int)incr;

    // The phase transitions below change exactly when the new view is valid.  So we need to increase the
    // phase by half a leaf so that the exact valid point is halfway through the period the leaf is active.
    // except that we have to be careful at the transitions
    phase = EC_fmod(phase, M_PI * 2);
    double halfLeafSpan = 0.5/leavesPerQuadrant*(M_PI/2);
    if (phase > M_PI) {
	phase -= halfLeafSpan;
	if (ECTerminatorQuadrantIsLeft(quadrant) && phase < M_PI) {
	    phase = M_PI + 0.01;
	}
    } else {
	phase += halfLeafSpan;
	if (ECTerminatorQuadrantIsRight(quadrant) && phase > M_PI) {
	    phase = M_PI - 0.01;
	}
    }

    // There are four phase cycles that we're interested in:
    //    Waxing crescent, in which the right side leaves fall off gradually from 0 to n
    //    Waxing gibbous, in which the left side leaves retreat gradually from n to 0
    //    Waning gibbous, in which the right side leaves advance gradually from 0 to n
    //    Waning crescent, in which the left side leaves reassemble gradually from n to 0

    // The angle for a top leaf is identical to the angle for a bottom leaf, except that the sign is reversed

    // The right leaf angles for waxing crescent are the same as the left leaf angles for waning crescent, except that
    // the sign of the leaf angle is reversed, and the phase direction is inverted within the cycle.  This is generally true
    // for right and left.  So if we simply define the bottom right leaf, then we can define the angles for the others as
    // follows, where P' is the 'inverted phase angle', which is (pi - P) mod 2pi.
    //    Aur(P) = -Alr(P)
    //    All(P) = -Alr(P')
    //    Aul(P) = Alr(P')

    // To arrange this, we change P to P' here for the left leaves, and then swap the sign at the end for ur and ll
    if (ECTerminatorQuadrantIsLeft(quadrant)) {
	phase = 2*M_PI - phase;
    }

    // So at this point we just assume we're on the lower right

    double innerPhase = phaseAngleForInnerTerminatorEdgeForcingLowerRight(true, quadrant, indexWithinQuadrant, leavesPerQuadrant);
    double outerPhase = phaseAngleForOuterTerminatorEdgeForcingLowerRight(true, quadrant, indexWithinQuadrant, leavesPerQuadrant);
    double outerEndPhase = innerPhase - M_PI;
    double innerStartPhase = outerPhase + M_PI;

    // Assume radius = 1.0; this routine can't possibly depend on the value of radius, and that simplifies the arithmetic

    double returnAngle;
    if (phase < outerPhase) {
	return 0;  // no sign changes required
    } else if (phase < outerEndPhase) {
	// rotate the leaves inward, that is, by a negative angle from the lower right anchor
	
	// Where the outer terminator line intercepts the equator:
	double xOuterIntercept = /* radius * */cos(outerPhase);
	double outerReferenceAngle = atan(xOuterIntercept/* /radius */);
	//printf("outerRef %.1f\n", outerReferenceAngle * 180 / M_PI);

	// Where the inner terminator line of the next leaf intercepts the equator:
	double xInnerIntercept = /* radius * */ cos(outerEndPhase);
	double rOuter = sqrt(xOuterIntercept * xOuterIntercept + /* radius * radius */ 1.0);

	// Now calculate angle where the original (xOuterIntercept, 0) is directly above (xInnerIntercept, 0):
	double innerReferenceAngle = asin(xInnerIntercept/rOuter);
	//printf("innerRef %.1f\n", innerReferenceAngle * 180 / M_PI);

	//printf("Phase cycle: %.3f\n", (phase - outerPhase)/(outerEndPhase - outerPhase));

	// Now interpolate between the two phases;
	if (incremental) {
	    returnAngle = (phase - outerPhase)/(outerEndPhase - outerPhase)*(innerReferenceAngle - outerReferenceAngle);
	} else {
	    return 0;
	}
	//printf("return %.1f\n", returnAngle * 180 / M_PI);

    } else if (phase < innerStartPhase) {
	// parkAngle is 90 for i=n-1
	// parkAngle is close to zero for i=0
	returnAngle = M_PI / 2 * (indexWithinQuadrant + 1.0)/(leavesPerQuadrant);
	//printf("parkAngle %.1f for index %d and leaves %d\n",
	// returnAngle * 180 / M_PI, indexWithinQuadrant, leavesPerQuadrant);
    } else if (phase < innerPhase) {
	// rotate the leaves outward, that is, by a positive angle from the lower right anchor
	
	// Where the inner terminator line intercepts the equator:
	double xInnerIntercept = /* radius * */ cos(innerPhase);
	double innerReferenceAngle = atan(xInnerIntercept/* /radius */);
	//printf("innerRef %.1f\n", innerReferenceAngle * 180 / M_PI);

	// Where the outer terminator line of the next leaf intercepts the equator:
	double xOuterIntercept = /* radius * */ cos(innerStartPhase);
	double rInner = sqrt(xInnerIntercept * xInnerIntercept + /* radius * radius */ 1.0);

	// Now calculate angle where the original (xInnerIntercept, 0) is directly above (xOuterIntercept, 0):
	double outerReferenceAngle = asin(xOuterIntercept/rInner);
	//printf("innerRef %.1f\n", innerReferenceAngle * 180 / M_PI);

	//printf("Phase cycle: %.3f\n", (phase - outerPhase)/(outerEndPhase - outerPhase));

	// Now interpolate between the two phases;
	if (incremental) {
	    returnAngle = -(phase - innerPhase)/(innerStartPhase - innerPhase)*(outerReferenceAngle - innerReferenceAngle);
	} else {
	    return 0;
	}
	//printf("return %.1f\n", returnAngle * 180 / M_PI);

    } else {
	return 0;  // no sign changes required
    }
    
    if (quadrant == ECTerminatorUpperRight || quadrant == ECTerminatorLowerLeft) {
	return -returnAngle;
    }

    return returnAngle;
}

#ifndef NDEBUG
void testTerminatorOp(void) {
    int numSteps = 360;
    int indexWithinQuad = 0;
    int leavesPerQuad = 2;
    int quadrant = ECTerminatorLowerRight;
    for (int step = 0; step < numSteps; step++) {
	double phase = step * (M_PI * 2) / numSteps;
	double termAngle = EB_terminatorAngle(phase, quadrant, indexWithinQuad, leavesPerQuad, 0, NULL);
	printf("%3d: %.2f\n", step, termAngle * 180 / M_PI);
    }
}
#endif

// make sounds //hack?

EBVM_OP0(tick)
{
    //    [AudioFX playAtPath:@"tick.caf"];
    return 1.0;
}

EBVM_OP0(tock)
{
//    [AudioFX playAtPath:@"tock.caf"];
    return 1.0;
}

EBVM_OP0(snap)
{
//    [AudioFX playAtPath:@"Snap.caf"];
    return 1.0;
}

EBVM_OP0(honk)
{
//    [AudioFX playAtPath:@"honk.caf"];
    return 1.0;
}

EBVM_OP0(globalTimes)
{
#ifdef SHAREDCLOCK
    return [ECWatchEnvironment globalTimes];
#else
    return 0;
#endif
}

EBVM_OP0(batteryLevel)
{
    return [ChronometerAppDelegate batteryLevel];
}

EBVM_OP0(singleWatchProduct)
{
    return ECSingleWatchProduct;
}

EBVM_OP0(toggleGlobalTimes)
{
#ifdef SHAREDCLOCK
    [ECWatchEnvironment setGlobalTimes:![ECWatchEnvironment globalTimes]];
    return [ECWatchEnvironment globalTimes];
#else
    return 0;
#endif
}

EBVM_OP1(saveBody, val)
{
    ECGLWatch *watch = [virtualMachine owner];
    [[NSUserDefaults standardUserDefaults] setDouble:val forKey:[watch.name stringByAppendingString:@"-body"]];
    return 0;
}

EBVM_OP0(dump)
{
#ifndef NDEBUG
    [[virtualMachine owner] dumpVariableValues];
#endif
    return 1.0;
}

EBVM_OP1(planetMoonAgeAngle, planetNumber)
{
    ECAstronomyManager *astro = [[virtualMachine owner] mainAstro];
    double age;
    switch((int)planetNumber) {
      case ECPlanetMercury:
      case ECPlanetVenus:
      case ECPlanetEarth:
      case ECPlanetMars:
      case ECPlanetJupiter:
      case ECPlanetSaturn:
      case ECPlanetUranus:
      case ECPlanetNeptune:
        age = [astro planetMoonAgeAngle:(int)planetNumber];
        break;
      case ECPlanetSun:
        age = M_PI;  // Always bright :-)
        break;
      case ECPlanetMoon:  // We have a different method for the Moon phase angle
        age = [astro moonAgeAngle];
        break;
      case ECPlanetPluto:
      default:
        assert(false);
        return 0;
    }
    // char buf[256];
    // sprintf(buf, "planetMoonAgeAngle for planet number %d", (int)planetNumber);
    // printAngle(age, buf);
    return age;
}

EBVM_OP1(planetRelativePositionAngle, planetNumber)
{
    ECAstronomyManager *astro = [[virtualMachine owner] mainAstro];
    double angle;
    switch((int)planetNumber) {
      case ECPlanetMercury:
      case ECPlanetVenus:
      case ECPlanetEarth:
      case ECPlanetMars:
      case ECPlanetJupiter:
      case ECPlanetSaturn:
      case ECPlanetUranus:
      case ECPlanetNeptune:
        angle = [astro planetRelativePositionAngle:(int)planetNumber];
        break;
      case ECPlanetSun:
        angle = 0;  // No terminator, so arbitrary angle
        break;
      case ECPlanetMoon:  // We have a different method for the Moon
        angle = [astro moonRelativePositionAngle];
        break;
      case ECPlanetPluto:
      default:
        assert(false);
        return 0;
    }
    // char buf[256];
    // sprintf(buf, "planetRelativePositionAngle for planet number %d", (int)planetNumber);
    // printAngle(angle, buf);
    return angle;
}

// Returns the DEL of the Moon at midnight LT on the day with the given offset from midnight today.
// Is imprecise in the presence of DST changes.
EBVM_OP1(moonDeltaEclipticLongitudeAtDeltaDay, deltaDay)
{
    double secondsSinceMidnightToday = [[virtualMachine owner] getValueFromMainTime:@selector(secondsSinceMidnightValueUsingEnv:)];
    double now = [[[virtualMachine owner] mainTime] currentTime];
    double requestedTime = now - secondsSinceMidnightToday + (deltaDay * 24 * 3600);
    return [ECAstronomyManager moonDeltaEclipticLongitudeAtDateInterval:requestedTime];
}

EBVM_OP0(VeneziaTapsEnabled)
{
    return 1.0;  // No settings for CwHA
}

EBVM_OP0(demoControlPause)
{
    printf("demoControlPause tapped\n");
    return 0;
}

EBVM_OP0(demoControlOnscreen)
{
    return 1.0;  // No settings for CwHA
}

