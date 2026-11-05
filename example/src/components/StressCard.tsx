import { Pressable, StyleSheet, Text, View } from 'react-native';

import type { PropsWithChildren } from 'react';

interface StressCardProps {
  title: string;
  description: string;
  actionLabel: string;
  isActive?: boolean;
  onPress: () => void;
}

export function StressCard({
  title,
  description,
  actionLabel,
  isActive = false,
  onPress,
  children,
}: PropsWithChildren<StressCardProps>) {
  return (
    <View style={styles.card}>
      <View style={styles.header}>
        <View style={styles.texts}>
          <Text style={styles.title}>{title}</Text>
          <Text style={styles.description}>{description}</Text>
        </View>
        <Pressable
          accessibilityRole="button"
          onPress={onPress}
          style={({ pressed }) => [
            styles.button,
            isActive && styles.buttonActive,
            pressed && styles.buttonPressed,
          ]}
        >
          <Text
            style={[styles.buttonLabel, isActive && styles.buttonLabelActive]}
          >
            {actionLabel}
          </Text>
        </Pressable>
      </View>
      {children}
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    gap: 12,
    padding: 16,
    borderRadius: 20,
    borderCurve: 'continuous',
    backgroundColor: '#17171C',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: 'rgba(255, 255, 255, 0.08)',
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  texts: {
    flex: 1,
    gap: 4,
  },
  title: {
    color: '#F5F5F7',
    fontSize: 16,
    fontWeight: '600',
  },
  description: {
    color: '#9CA3AF',
    fontSize: 13,
    lineHeight: 18,
  },
  button: {
    paddingHorizontal: 14,
    paddingVertical: 9,
    borderRadius: 999,
    backgroundColor: 'rgba(255, 255, 255, 0.08)',
  },
  buttonActive: {
    backgroundColor: '#34D399',
  },
  buttonPressed: {
    opacity: 0.7,
  },
  buttonLabel: {
    color: '#F5F5F7',
    fontSize: 13,
    fontWeight: '600',
  },
  buttonLabelActive: {
    color: '#052E1C',
  },
});
