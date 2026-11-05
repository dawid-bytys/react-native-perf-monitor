#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, RNPMThermalState) {
  RNPMThermalStateUnknown = -1,
  RNPMThermalStateNominal = 0,
  RNPMThermalStateFair = 1,
  RNPMThermalStateSerious = 2,
  RNPMThermalStateCritical = 3,
};

typedef struct {
  double frames;
  double intervalMs;
  double commits;
  double renderTotalMs;
  double renderMaxMs;
  double heapUsedBytes;
  double heapTotalBytes;
  double activeRequests;
} RNPMJsReport;

typedef struct {
  double uiFps;
  double displayHz;
  NSInteger droppedFrames;
  BOOL hasJsMetrics;
  BOOL isJsStalled;
  double jsFps;
  double jsTargetFps;
  double cpuPercent;
  NSInteger cpuCores;
  double memoryBytes;
  double jsHeapUsedBytes;
  double jsHeapTotalBytes;
  NSInteger viewCount;
  double reactCommitsPerSecond;
  double reactRenderAvgMs;
  double reactRenderMaxMs;
  double networkDownBytesPerSecond;
  double networkUpBytesPerSecond;
  NSInteger activeRequests;
  RNPMThermalState thermalState;
} RNPMSnapshot;
