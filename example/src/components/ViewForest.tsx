import { StyleSheet, View } from 'react-native';

const TREE_COUNT = 400;
const TREE_INDEXES = Array.from(
  {
    length: TREE_COUNT,
  },
  (_, index) => index
);

export function ViewForest() {
  return (
    <View style={styles.forest}>
      {TREE_INDEXES.map((index) => (
        <View key={index} collapsable={false} style={styles.tree}>
          <View collapsable={false} style={styles.crown}>
            <View collapsable={false} style={styles.leaf} />
          </View>
          <View collapsable={false} style={styles.trunk} />
        </View>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  forest: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 2,
  },
  tree: {
    width: 10,
    alignItems: 'center',
  },
  crown: {
    width: 10,
    height: 10,
    borderRadius: 5,
    backgroundColor: '#065F46',
    alignItems: 'center',
    justifyContent: 'center',
  },
  leaf: {
    width: 4,
    height: 4,
    borderRadius: 2,
    backgroundColor: '#34D399',
  },
  trunk: {
    width: 2,
    height: 4,
    backgroundColor: '#78350F',
  },
});
