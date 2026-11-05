import { useRef, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { PerfMonitor } from '@dawid-bytys/react-native-perf-monitor';
import { StatusBar } from 'expo-status-bar';

import { RenderStorm } from './components/RenderStorm';
import { StressCard } from './components/StressCard';
import { ViewForest } from './components/ViewForest';
import { allocateJsHeap } from './stress/allocateJsHeap';
import { blockJsThread } from './stress/blockJsThread';
import { downloadPayload } from './stress/downloadPayload';

const BLOCK_DURATION_MS = 2000;
const DOWNLOAD_BYTES = 50_000_000;
const HEAP_ALLOCATION_MB = 32;

type DownloadState = 'idle' | 'downloading' | 'done' | 'failed';

const DOWNLOAD_LABELS: Record<DownloadState, string> = {
  idle: 'Download',
  downloading: 'Loading…',
  done: 'Again',
  failed: 'Retry',
};

export default function App() {
  const [isRenderStormActive, setIsRenderStormActive] = useState(false);
  const [isForestVisible, setIsForestVisible] = useState(false);
  const [downloadState, setDownloadState] = useState<DownloadState>('idle');
  const [heapAllocationCount, setHeapAllocationCount] = useState(0);
  const heapAllocations = useRef<unknown[]>([]);

  async function handleDownload() {
    setDownloadState('downloading');

    try {
      await downloadPayload(DOWNLOAD_BYTES);
      setDownloadState('done');
    } catch {
      setDownloadState('failed');
    }
  }

  function handleHeapAllocation() {
    if (heapAllocations.current.length > 0) {
      heapAllocations.current = [];
      setHeapAllocationCount(0);
      return;
    }

    heapAllocations.current = [allocateJsHeap(HEAP_ALLOCATION_MB)];
    setHeapAllocationCount(HEAP_ALLOCATION_MB);
  }

  return (
    <View style={styles.screen}>
      <StatusBar style="light" />
      <ScrollView
        contentInsetAdjustmentBehavior="automatic"
        contentContainerStyle={styles.content}
      >
        <View style={styles.hero}>
          <Text style={styles.eyebrow}>react-native-perf-monitor</Text>
          <Text style={styles.title}>Stress lab</Text>
          <Text style={styles.subtitle}>
            Open the dev menu and pick “Show Perf Monitor”, or use the buttons
            below. Every card pushes a different metric.
          </Text>
          <View style={styles.monitorActions}>
            <Pressable
              accessibilityRole="button"
              onPress={PerfMonitor.toggle}
              style={({ pressed }) => [
                styles.primaryButton,
                pressed && styles.primaryButtonPressed,
              ]}
            >
              <Text style={styles.primaryButtonLabel}>Toggle monitor</Text>
            </Pressable>
          </View>
        </View>

        <StressCard
          title="Block the JS thread"
          description="Runs a busy loop for 2 seconds. JS FPS drops to zero while the UI keeps animating."
          actionLabel="Block"
          onPress={() => blockJsThread(BLOCK_DURATION_MS)}
        />

        <StressCard
          title="Render storm"
          description="Re-renders 240 views on every frame. Watch React commits per second and render time."
          actionLabel={isRenderStormActive ? 'Stop' : 'Start'}
          isActive={isRenderStormActive}
          onPress={() => setIsRenderStormActive((isActive) => !isActive)}
        >
          {isRenderStormActive && <RenderStorm />}
        </StressCard>

        <StressCard
          title="Mount 1,600 views"
          description="Mounts a forest of non-collapsible native views. The native view count jumps."
          actionLabel={isForestVisible ? 'Unmount' : 'Mount'}
          isActive={isForestVisible}
          onPress={() => setIsForestVisible((isVisible) => !isVisible)}
        >
          {isForestVisible && <ViewForest />}
        </StressCard>

        <StressCard
          title="Download 50 MB"
          description="Fetches a payload from Cloudflare. Network throughput and active requests go up."
          actionLabel={DOWNLOAD_LABELS[downloadState]}
          isActive={downloadState === 'downloading'}
          onPress={handleDownload}
        />

        <StressCard
          title="Allocate JS heap"
          description="Keeps ~32 MB of JS objects alive. JS heap and memory grow, then drop after release and GC."
          actionLabel={heapAllocationCount > 0 ? 'Release' : 'Allocate'}
          isActive={heapAllocationCount > 0}
          onPress={handleHeapAllocation}
        />
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: '#0B0B0F',
  },
  content: {
    gap: 12,
    padding: 16,
    paddingBottom: 48,
  },
  hero: {
    gap: 8,
    paddingTop: 24,
    paddingBottom: 12,
  },
  eyebrow: {
    color: '#34D399',
    fontSize: 12,
    fontWeight: '600',
    letterSpacing: 1.2,
    textTransform: 'uppercase',
  },
  title: {
    color: '#F5F5F7',
    fontSize: 34,
    fontWeight: '700',
  },
  subtitle: {
    color: '#9CA3AF',
    fontSize: 15,
    lineHeight: 21,
  },
  monitorActions: {
    flexDirection: 'row',
    marginTop: 8,
  },
  primaryButton: {
    paddingHorizontal: 18,
    paddingVertical: 12,
    borderRadius: 999,
    backgroundColor: '#F5F5F7',
  },
  primaryButtonPressed: {
    opacity: 0.8,
  },
  primaryButtonLabel: {
    color: '#0B0B0F',
    fontSize: 15,
    fontWeight: '600',
  },
});
