import { useEffect, useState } from 'react';
import { StyleSheet, View } from 'react-native';

const CELL_COUNT = 240;
const CELL_INDEXES = Array.from(
  {
    length: CELL_COUNT,
  },
  (_, index) => index
);

function cellColor(index: number, tick: number) {
  const hue = (index * 7 + tick * 9) % 360;

  return `hsl(${hue}, 70%, 60%)`;
}

export function RenderStorm() {
  const [tick, setTick] = useState(0);

  useEffect(() => {
    let frameRequestId = requestAnimationFrame(function handleFrame() {
      setTick((previousTick) => previousTick + 1);
      frameRequestId = requestAnimationFrame(handleFrame);
    });

    return () => cancelAnimationFrame(frameRequestId);
  }, []);

  return (
    <View style={styles.grid}>
      {CELL_INDEXES.map((index) => (
        <View
          key={index}
          style={[
            styles.cell,
            {
              backgroundColor: cellColor(index, tick),
            },
          ]}
        />
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  grid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 3,
  },
  cell: {
    width: 14,
    height: 14,
    borderRadius: 3,
  },
});
