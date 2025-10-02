# Contributing to Zipline Native Client

First off, thanks for taking the time to contribute! This app exists because people like you make open source awesome.

## Code of Conduct

Be cool. Don't be a jerk. We're all here to make file sharing better.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues to avoid duplicates. When you create a bug report, include as many details as possible:

- **Use a clear and descriptive title**
- **Describe the exact steps to reproduce the problem**
- **Provide specific examples**
- **Include screenshots if relevant**
- **Include device information** (Android version, phone model)
- **Include debug logs** (Settings → Debug → View Logs)

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion:

- **Use a clear and descriptive title**
- **Provide a detailed description of the suggested enhancement**
- **Explain why this enhancement would be useful**
- **List any similar apps that have this feature** (if applicable)

### Pull Requests

The process is pretty standard:

1. Fork the repo
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run the checks (`flutter analyze --no-fatal-infos`, `flutter test`, `npm test --prefix cloudflare-oauth-redirect`)
5. Commit your changes (`git commit -m 'Add some amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## Development Setup

### Prerequisites

- Flutter SDK 3.35.0+
- Node.js 18+
- Android Studio or VS Code
- Android device or emulator for testing
- A Zipline server instance for integration tests

### Getting Started

```bash
# Clone your fork
git clone https://github.com/your-username/zipline-native.git
cd zipline-native

# Install dependencies
flutter pub get
npm install --prefix cloudflare-oauth-redirect

# Run the app
flutter run
```

### Building for Release

See the main README for detailed build instructions. Quick version:

```bash
# Build APKs
flutter build apk --release --split-per-abi
```

## Code Style

### Dart/Flutter Guidelines

- Follow the official [Dart style guide](https://dart.dev/guides/language/effective-dart/style)
- Use `flutter format` before committing
- Keep widgets small and focused
- Prefer composition over inheritance
- Extract complex logic into services

### Git Commit Messages

- Use the present tense ("Add feature" not "Added feature")
- Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
- Limit the first line to 72 characters
- Reference issues and pull requests when relevant

Good examples:
- `fix: resolve OAuth redirect loop on Android 14`
- `feat: add bulk file selection in library`
- `docs: update Cloudflare Worker setup instructions`
- `refactor: extract upload logic into service`

### Code Comments

- Write self-documenting code that doesn't need comments
- When comments are necessary, explain WHY not WHAT
- No commented-out code in commits
- Update comments when you change the code

## Testing

### Running Tests

```bash
# Static analysis
flutter analyze --no-fatal-infos
# Dart / Flutter test suite
flutter test

# Cloudflare Worker tests
npm test --prefix cloudflare-oauth-redirect

# Optional coverage run
flutter test --coverage
```

### Writing Tests

- Test files go in the `test/` directory
- Mirror the `lib/` structure in `test/`
- Focus on testing business logic in services
- Widget tests for complex UI components
- Integration tests for critical user flows

## Project Structure

```
lib/
├── core/           # Constants, config, themes
├── models/         # Data models
├── screens/        # UI screens/pages
├── services/       # Business logic, API calls
└── widgets/        # Reusable UI components
```

### Adding New Features

1. **Discuss first** - Open an issue to discuss major changes
2. **Keep it focused** - One feature per PR
3. **Update documentation** - Including README if needed
4. **Add tests** - At least try to
5. **Check existing patterns** - Follow the established architecture

## Platform-Specific Contributions

### iOS Support

iOS should theoretically work but is untested. If you have an iPhone and want to help:

1. Test the app on iOS
2. Document any issues
3. Submit fixes for iOS-specific problems
4. Update the README with iOS build instructions

### Other Platforms

- **Windows/macOS/Linux**: Desktop support would be cool
- **Web**: Would defeat the purpose, but hey, if you want to...

## Things That Need Work

Current areas that could use contributions:

- [ ] Comprehensive test coverage across services and widgets
- [ ] iOS testing and fixes
- [ ] Tablet UI optimization
- [ ] Localization/internationalization
- [ ] Performance optimizations
- [ ] Accessibility improvements
- [ ] Light theme (for the monsters who use it)

## Questions?

Feel free to:
- Open an issue for discussion
- Ask questions in existing issues/PRs
- Reach out in PR comments

## Recognition

Contributors get:
- Their name in the git history (immortality!)
- Gratitude from users who benefit from your work
- The warm fuzzy feeling of contributing to open source
- Bragging rights

## Final Notes

- Don't be discouraged if your first PR needs changes
- Ask questions if you're unsure about something
- Small contributions are valuable too (typos, docs, etc.)
- Have fun with it!

Remember: this project started because someone wanted to share files from their phone without opening a browser. Your contribution, no matter how small, helps make that experience better for everyone.

---

*P.S. – If you lean on AI tooling, double-check the output and run the full test suite before opening your PR.*
