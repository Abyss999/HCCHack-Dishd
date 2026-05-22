import { Tabs } from "expo-router";
import { SymbolView } from "expo-symbols";
import { useTheme } from "@/context/ThemeContext";

export default function TabsLayout() {
  const { resolvedScheme } = useTheme();
  const isDark = resolvedScheme === "dark";

  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarStyle: {
          backgroundColor: isDark ? "#262626" : "#ffffff",
          borderTopColor: isDark ? "#404040" : "#e8e3dc",
          borderTopWidth: 1,
          paddingBottom: 8,
          paddingTop: 8,
          height: 60,
        },
        tabBarLabelStyle: {
          fontSize: 12,
          fontFamily: "Roboto",
          marginTop: 2,
        },
        tabBarActiveTintColor: "#d97757",
        tabBarInactiveTintColor: isDark ? "#808080" : "#a8a29e",
      }}
    >
      <Tabs.Screen
        name="index"
        options={{
          title: "Home",
          tabBarLabel: "Home",
          tabBarIcon: ({ color, focused }) => (
            <SymbolView
              name={focused ? "house.fill" : "house"}
              tintColor={color}
              size={24}
              resizeMode="scaleAspectFit"
            />
          ),
        }}
      />
      <Tabs.Screen
        name="profile"
        options={{
          title: "Profile",
          tabBarLabel: "Profile",
          tabBarIcon: ({ color, focused }) => (
            <SymbolView
              name={focused ? "person.fill" : "person"}
              tintColor={color}
              size={24}
              resizeMode="scaleAspectFit"
            />
          ),
        }}
      />
    </Tabs>
  );
}
