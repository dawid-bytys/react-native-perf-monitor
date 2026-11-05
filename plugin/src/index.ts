import {
  AndroidConfig,
  createRunOncePlugin,
  withAndroidManifest,
  withInfoPlist,
} from 'expo/config-plugins';

import type { ConfigPlugin } from 'expo/config-plugins';

const packageJson = require('../../package.json');

export interface PerfMonitorPluginProps {
  replaceDevMenu?: boolean;
  showOnLaunch?: boolean;
}

type ResolvedPerfMonitorPluginProps = Required<PerfMonitorPluginProps>;

const IOS_REPLACE_DEV_MENU_KEY = 'RNPerfMonitorReplaceDevMenu';
const IOS_SHOW_ON_LAUNCH_KEY = 'RNPerfMonitorShowOnLaunch';
const ANDROID_REPLACE_DEV_MENU_KEY = 'com.perfmonitor.REPLACE_DEV_MENU';
const ANDROID_SHOW_ON_LAUNCH_KEY = 'com.perfmonitor.SHOW_ON_LAUNCH';

const withPerfMonitorIos: ConfigPlugin<ResolvedPerfMonitorPluginProps> = (
  config,
  props
) => {
  return withInfoPlist(config, (infoPlistConfig) => {
    infoPlistConfig.modResults[IOS_REPLACE_DEV_MENU_KEY] = props.replaceDevMenu;
    infoPlistConfig.modResults[IOS_SHOW_ON_LAUNCH_KEY] = props.showOnLaunch;

    return infoPlistConfig;
  });
};

const withPerfMonitorAndroid: ConfigPlugin<ResolvedPerfMonitorPluginProps> = (
  config,
  props
) => {
  return withAndroidManifest(config, (manifestConfig) => {
    const mainApplication = AndroidConfig.Manifest.getMainApplicationOrThrow(
      manifestConfig.modResults
    );

    AndroidConfig.Manifest.addMetaDataItemToMainApplication(
      mainApplication,
      ANDROID_REPLACE_DEV_MENU_KEY,
      String(props.replaceDevMenu)
    );
    AndroidConfig.Manifest.addMetaDataItemToMainApplication(
      mainApplication,
      ANDROID_SHOW_ON_LAUNCH_KEY,
      String(props.showOnLaunch)
    );

    return manifestConfig;
  });
};

const withPerfMonitor: ConfigPlugin<PerfMonitorPluginProps | void> = (
  config,
  props
) => {
  const resolvedProps: ResolvedPerfMonitorPluginProps = {
    replaceDevMenu: props?.replaceDevMenu ?? true,
    showOnLaunch: props?.showOnLaunch ?? false,
  };

  return withPerfMonitorAndroid(
    withPerfMonitorIos(config, resolvedProps),
    resolvedProps
  );
};

export default createRunOncePlugin(
  withPerfMonitor,
  packageJson.name,
  packageJson.version
);
