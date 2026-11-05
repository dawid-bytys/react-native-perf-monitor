#import "RNPMConfiguration.h"

static NSString *const RNPMReplaceDevMenuKey = @"RNPerfMonitorReplaceDevMenu";
static NSString *const RNPMShowOnLaunchKey = @"RNPerfMonitorShowOnLaunch";
static NSString *const RNPMDevSettingsDefaultsKey = @"RCTDevMenu";
static NSString *const RNPMDevSettingsPerfMonitorKey = @"RCTPerfMonitorKey";

static BOOL RNPMReadInfoPlistBool(NSString *key, BOOL defaultValue)
{
  id value = [[NSBundle mainBundle] objectForInfoDictionaryKey:key];

  return [value respondsToSelector:@selector(boolValue)] ? [value boolValue] : defaultValue;
}

BOOL RNPMConfigurationReplacesDevMenu(void)
{
  return RNPMReadInfoPlistBool(RNPMReplaceDevMenuKey, YES);
}

BOOL RNPMConfigurationShowsOnLaunch(void)
{
  return RNPMReadInfoPlistBool(RNPMShowOnLaunchKey, NO);
}

BOOL RNPMConfigurationWasShownByDevMenu(void)
{
  NSDictionary *devSettings = [[NSUserDefaults standardUserDefaults] dictionaryForKey:RNPMDevSettingsDefaultsKey];

  return [devSettings[RNPMDevSettingsPerfMonitorKey] boolValue];
}
