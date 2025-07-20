# TrackMe

> A 100% local, privacy-first productivity tracker for macOS

TrackMe is a native Swift macOS application that automatically tracks your keystrokes and app usage to help you understand and improve your productivity patterns. Built with SwiftUI and SwiftData, it provides beautiful real-time visualizations while keeping all your data completely local and private.

## 🎯 Why?

- **Privacy**: Your data never leaves your Mac - everything runs completely locally
- **Self-awareness**: Understand where your time actually goes throughout the day
- **Fight procrastination**: Visual feedback helps you stay accountable to your productivity goals
- **Beautiful insights**: Real-time, interactive visualizations built with SwiftUI Charts

## ✨ Features

- **Automatic keystroke tracking**: Monitor typing patterns and productivity intensity
- **App usage monitoring**: Track which applications consume your time
- **Real-time visualizations**: Beautiful charts showing daily, weekly, monthly, and yearly patterns
- **Focus session tracking**: Monitor deep work sessions and productivity streaks
- **Daily statistics**: Comprehensive analytics of your computing habits
- **Background operation**: Runs silently without interrupting your workflow
- **Zero data collection**: Everything stays on your device

## 🏗️ Project Structure

```
TrackMe/
├── TrackMe/
│   ├── TrackMeApp.swift          # Main app entry point
│   ├── ContentView.swift         # Primary dashboard interface
│   ├── RootView.swift           # Root navigation container
│   └── Data/                    # Core data models
│       ├── AppLog.swift         # Application usage tracking
│       ├── KeyLog.swift         # Keystroke logging
│       ├── DailyStats.swift     # Daily productivity statistics
│       ├── Focus.swift          # Focus session data
│       └── Controllers/         # Data management
│   └── Features/                # Feature modules
│       ├── AppUsage/           # App usage analytics
│       ├── Logger/             # Logging infrastructure
│       └── Settings/           # User preferences
│   └── Shared/                 # Utility components
└── TrackMe.xcodeproj/          # Xcode project files
```

## 🚀 Getting Started

### Prerequisites

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later
- Swift 5.9 or later

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/quanghuynt14/TrackMe.git
   cd TrackMe
   ```

2. **Open in Xcode**
   ```bash
   open TrackMe.xcodeproj
   ```

3. **Grant permissions**
   - Go to System Preferences → Security & Privacy → Privacy
   - Enable "Accessibility" access for TrackMe
   - Enable "Input Monitoring" for keystroke tracking

4. **Build and run**
   - Select your target device/simulator
   - Press `Cmd + R` to build and run

### First Launch Setup

When you first launch TrackMe, you'll need to:

1. Grant accessibility permissions for app monitoring
2. Grant input monitoring permissions for keystroke tracking
3. Configure your focus session preferences in Settings

## 📊 Features Overview

### Keystroke Analytics
- Real-time keystroke frequency monitoring
- Daily, weekly, and monthly keystroke patterns
- Productivity intensity heatmaps
- Typing rhythm analysis

### App Usage Tracking
- Automatic detection of active applications
- Time spent in each application
- App switching patterns
- Productivity vs. distraction categorization

### Focus Sessions
- Deep work session detection
- Focus streak tracking
- Productivity score calculation
- Goal setting and achievement tracking

### Data Visualization
- Interactive SwiftUI charts
- Multiple timeframe views (day/week/month/year)
- Real-time updates
- Export capabilities for further analysis

## 🛡️ Privacy & Security

TrackMe is built with privacy as a core principle:

- **100% Local**: All data processing happens on your device
- **No network access**: The app doesn't connect to the internet
- **Encrypted storage**: All data is stored using SwiftData with encryption
- **User control**: Complete control over your data with export and deletion options
- **Transparent logging**: Open source codebase for full transparency

## 🤝 Contributing

We welcome contributions! Here's how you can help:

### Focus Areas
- 🎯 **Core tracking**: Improve keystroke and app detection accuracy
- 📊 **Visualizations**: Enhance charts and analytics dashboards
- ⚡ **Performance**: Optimize background processing and data queries
- 🎨 **UI/UX**: Improve the user interface and experience
- 🔧 **Settings**: Expand configuration and customization options

### Development Setup

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes and test thoroughly
4. Commit your changes: `git commit -m 'Add amazing feature'`
5. Push to the branch: `git push origin feature/amazing-feature`
6. Open a Pull Request

## 🙏 Inspiration

This project was inspired by [**ulogme**](https://github.com/karpathy/ulogme) by [@karpathy](https://github.com/karpathy) - a fantastic productivity tracking tool that pioneered the concept of automatic computer usage visualization. While ulogme focuses on Ubuntu/Linux environments with web-based visualization, TrackMe brings these powerful concepts to macOS with a native Swift implementation.

Special thanks to Andrej Karpathy for the original vision of quantifying productivity through automated tracking and beautiful visualizations.

## 📜 License

MIT License - see the [LICENSE](LICENSE) file for details.

---

**Track your productivity. Understand your patterns. Take control of your time.**
