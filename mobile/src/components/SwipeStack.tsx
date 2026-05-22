import React, { useState } from "react";
import { View, Text } from "react-native";
import { Restaurant } from "@/types";
import { RestaurantCard } from "./RestaurantCard";
import { useColors } from "@/hooks/useColors";

interface SwipeStackProps {
  restaurants: Restaurant[];
  onSwipe: (restaurantId: string, direction: "yes" | "no") => void;
  onStackEmpty: () => void;
}

export const SwipeStack: React.FC<SwipeStackProps> = ({
  restaurants,
  onSwipe,
  onStackEmpty,
}) => {
  const colors = useColors();
  const [swipedIndexes, setSwipedIndexes] = useState<number[]>([]);

  const handleSwipeLeft = () => {
    const currentIndex = swipedIndexes.length;
    const restaurant = restaurants[currentIndex];
    if (restaurant) {
      onSwipe(restaurant.id, "no");
      setSwipedIndexes([...swipedIndexes, currentIndex]);
      if (swipedIndexes.length + 1 >= restaurants.length) {
        onStackEmpty();
      }
    }
  };

  const handleSwipeRight = () => {
    const currentIndex = swipedIndexes.length;
    const restaurant = restaurants[currentIndex];
    if (restaurant) {
      onSwipe(restaurant.id, "yes");
      setSwipedIndexes([...swipedIndexes, currentIndex]);
      if (swipedIndexes.length + 1 >= restaurants.length) {
        onStackEmpty();
      }
    }
  };

  const currentIndex = swipedIndexes.length;
  const remainingCount = restaurants.length - currentIndex;

  if (remainingCount === 0) {
    return (
      <View style={{ flex: 1, justifyContent: "center", alignItems: "center" }}>
        <Text style={{ color: colors.text }} className="text-h1 font-dm-sans">
          No more restaurants
        </Text>
        <Text style={{ color: colors.textSecondary, marginTop: 8 }} className="text-body-sm">
          Waiting for results...
        </Text>
      </View>
    );
  }

  return (
    <View style={{ flex: 1 }}>
      <View style={{ flex: 1, justifyContent: "center", alignItems: "center", paddingHorizontal: 16 }}>
        {restaurants.slice(currentIndex, currentIndex + 2).map((restaurant, idx) => (
          <View
            key={restaurant.id}
            style={{
              position: "absolute",
              width: "100%",
              maxWidth: 384,
              zIndex: 100 - idx,
              transform: [{ scale: 1 - idx * 0.04 }, { translateY: idx * 10 }],
            }}
          >
            {idx === 0 ? (
              <RestaurantCard
                restaurant={restaurant}
                onSwipeLeft={handleSwipeLeft}
                onSwipeRight={handleSwipeRight}
              />
            ) : (
              <View
                style={{
                  borderRadius: 12,
                  borderWidth: 1,
                  borderColor: colors.cardBorder,
                  backgroundColor: colors.surface,
                  height: 480,
                }}
              />
            )}
          </View>
        ))}
      </View>

      <View style={{ paddingHorizontal: 16, paddingBottom: 16, paddingTop: 8 }}>
        <Text style={{ color: colors.textTertiary, textAlign: "center" }} className="text-caption">
          {remainingCount} restaurant{remainingCount !== 1 ? "s" : ""} remaining · swipe or tap
        </Text>
      </View>
    </View>
  );
};
