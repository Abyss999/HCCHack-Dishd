import { SafeAreaView, Text, View } from "react-native";

export default function Index() {
  return (
    <SafeAreaView className="flex-1 bg-neutral-950">
      <View className="flex-1 items-center justify-center px-6">
        <Text className="text-5xl font-bold text-white">DishMatch</Text>
        <Text className="mt-3 text-base text-neutral-400">
          Coming soon — design lands here.
        </Text>
      </View>
    </SafeAreaView>
  );
}
