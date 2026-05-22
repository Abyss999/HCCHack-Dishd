import React, { useEffect } from "react";
import { View, Text, Image, Pressable, Modal } from "react-native";
import Animated, {
  useSharedValue,
  useAnimatedStyle,
  withSpring,
  withSequence,
  withDelay,
} from "react-native-reanimated";
import { Restaurant } from "@/types";

interface MatchModalProps {
  visible: boolean;
  restaurant: Restaurant | null;
  onClose: () => void;
}

const COLORS = ["#d97757", "#f5a76d", "#c7622a", "#e8a885"];

interface ParticleProps {
  size: number;
  left: number;
  color: string;
}

const Particle: React.FC<ParticleProps> = ({ size, left, color }) => {
  const scale = useSharedValue(0);
  const opacity = useSharedValue(1);
  const translateY = useSharedValue(0);

  useEffect(() => {
    scale.value = withSpring(1, { damping: 0.6, mass: 0.5 });
    opacity.value = withSequence(withDelay(1200, withSpring(0, { damping: 0.6 })));
    translateY.value = withSequence(withDelay(1200, withSpring(-100, { damping: 0.8 })));
  }, []);

  const animStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }, { translateY: translateY.value }],
    opacity: opacity.value,
  }));

  return (
    <Animated.View
      style={[
        animStyle,
        {
          position: "absolute",
          left: `${left}%`,
          top: "50%",
          width: size,
          height: size,
          borderRadius: size / 2,
          backgroundColor: color,
        },
      ]}
    />
  );
};

const PARTICLES = Array.from({ length: 50 }, () => ({
  size: Math.random() * 8 + 4,
  left: Math.random() * 100,
  color: COLORS[Math.floor(Math.random() * COLORS.length)],
}));

const Confetti: React.FC = () => (
  <View className="absolute inset-0">
    {PARTICLES.map((p, i) => (
      <Particle key={i} size={p.size} left={p.left} color={p.color} />
    ))}
  </View>
);

export const MatchModal: React.FC<MatchModalProps> = ({
  visible,
  restaurant,
  onClose,
}) => {
  const scale = useSharedValue(0);
  const opacity = useSharedValue(0);

  useEffect(() => {
    if (visible) {
      scale.value = withSpring(1, { damping: 0.7, mass: 1, stiffness: 100 });
      opacity.value = withSpring(1, { damping: 0.7 });
    } else {
      scale.value = 0;
      opacity.value = 0;
    }
  }, [visible]);

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }],
    opacity: opacity.value,
  }));

  if (!restaurant) return null;

  return (
    <Modal
      visible={visible}
      transparent
      animationType="fade"
      onRequestClose={onClose}
    >
      <View className="flex-1 bg-black/80 justify-center items-center">
        <Confetti />

        <Animated.View
          style={[
            animatedStyle,
            {
              width: "85%",
              borderRadius: 24,
              backgroundColor: "#262626",
              overflow: "hidden",
            },
          ]}
        >
          {/* Image */}
          <Image
            source={{ uri: restaurant.photo_url ?? undefined }}
            className="w-full h-64 bg-neutral-surface"
            resizeMode="cover"
          />

          {/* Content */}
          <View className="p-6">
            {/* Celebration text */}
            <Text className="text-center font-dm-sans text-display-2 text-primary mb-2">
              It's a Match!
            </Text>

            {/* Restaurant info */}
            <View className="mb-6">
              <Text className="font-dm-sans text-h1 text-neutral-text mb-2">
                {restaurant.name}
              </Text>
              <Text className="text-body-sm text-neutral-text-secondary mb-3">
                {restaurant.address}
              </Text>

              {/* Meta */}
              <View className="flex-row gap-4 mb-3">
                <View className="flex-row items-center gap-1">
                  <Text className="text-body font-medium text-primary">★</Text>
                  <Text className="text-body-sm text-neutral-text-secondary">
                    {restaurant.rating != null ? restaurant.rating.toFixed(1) : "—"}
                  </Text>
                </View>
                <View className="flex-row items-center gap-1">
                  <Text className="text-body font-medium text-primary">$</Text>
                  <Text className="text-body-sm text-neutral-text-secondary">
                    {restaurant.price_tier?.length ?? 0}
                  </Text>
                </View>
              </View>

              {/* Cuisines */}
              <View className="flex-row flex-wrap gap-2">
                {restaurant.cuisine_tags.slice(0, 4).map((cuisine, idx) => (
                  <View
                    key={idx}
                    className="px-2 py-1 rounded-full bg-neutral-surface-light"
                  >
                    <Text className="text-caption text-neutral-text-secondary">
                      {cuisine}
                    </Text>
                  </View>
                ))}
              </View>
            </View>

            {/* Close button */}
            <Pressable
              onPress={onClose}
              className="bg-primary rounded-md py-3 items-center justify-center"
            >
              <Text className="text-white font-roboto font-medium">
                Continue
              </Text>
            </Pressable>
          </View>
        </Animated.View>
      </View>
    </Modal>
  );
};
