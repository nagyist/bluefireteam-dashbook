import 'package:dashbook/dashbook.dart';
import 'package:dashbook/src/device_size_extension.dart';
import 'package:dashbook/src/platform_utils/platform_utils.dart';
import 'package:dashbook/src/preferences.dart';
import 'package:dashbook/src/story_util.dart';
import 'package:dashbook/src/widgets/actions_container.dart';
import 'package:dashbook/src/widgets/dashbook_icon.dart';
import 'package:dashbook/src/widgets/device_settings_container.dart';
import 'package:dashbook/src/widgets/helpers.dart';
import 'package:dashbook/src/widgets/intructions_dialog.dart';
import 'package:dashbook/src/widgets/keys.dart';
import 'package:dashbook/src/widgets/preview_container.dart';
import 'package:dashbook/src/widgets/properties_container.dart';
import 'package:dashbook/src/widgets/select_device/device_settings.dart';
import 'package:dashbook/src/widgets/stories_list.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

typedef OnChapterChange = void Function(Chapter);

class _DashbookDualTheme {
  final ThemeData light;
  final ThemeData dark;
  final bool initWithLight;

  _DashbookDualTheme({
    required this.light,
    required this.dark,
    this.initWithLight = true,
  });
}

class _DashbookMultiTheme {
  final Map<String, ThemeData> themes;
  final String? initialTheme;

  _DashbookMultiTheme({
    required this.themes,
    this.initialTheme,
  });
}

class Dashbook extends StatefulWidget {
  final List<Story> stories = [];
  final ThemeData? theme;
  final _DashbookDualTheme? _dualTheme;
  final _DashbookMultiTheme? _multiTheme;
  final String title;
  final bool usePreviewSafeArea;
  final bool autoPinStoriesOnLargeScreen;
  final GlobalKey<NavigatorState>? navigatorKey;
  final List<LocalizationsDelegate<dynamic>>? localizationsDelegates;
  final List<Locale> supportedLocales;

  /// Called whenever a new chapter is selected.
  final OnChapterChange? onChapterChange;

  Dashbook({
    super.key,
    this.theme,
    this.title = '',
    this.usePreviewSafeArea = false,
    this.autoPinStoriesOnLargeScreen = false,
    this.navigatorKey,
    this.onChapterChange,
    this.localizationsDelegates,
    this.supportedLocales = const <Locale>[Locale('en', 'US')],
  })  : _dualTheme = null,
        _multiTheme = null;

  Dashbook.dualTheme({
    required ThemeData light,
    required ThemeData dark,
    super.key,
    bool initWithLight = true,
    this.title = '',
    this.usePreviewSafeArea = false,
    this.autoPinStoriesOnLargeScreen = false,
    this.navigatorKey,
    this.onChapterChange,
    this.localizationsDelegates,
    this.supportedLocales = const <Locale>[Locale('en', 'US')],
  })  : _dualTheme = _DashbookDualTheme(
          dark: dark,
          light: light,
          initWithLight: initWithLight,
        ),
        theme = null,
        _multiTheme = null;

  Dashbook.multiTheme({
    required Map<String, ThemeData> themes,
    super.key,
    String? initialTheme,
    this.title = '',
    this.usePreviewSafeArea = false,
    this.autoPinStoriesOnLargeScreen = false,
    this.navigatorKey,
    this.onChapterChange,
    this.localizationsDelegates,
    this.supportedLocales = const <Locale>[Locale('en', 'US')],
  })  : _multiTheme =
            _DashbookMultiTheme(themes: themes, initialTheme: initialTheme),
        theme = null,
        _dualTheme = null;

  Story storiesOf(String name) {
    final story = Story(name);
    stories.add(story);

    return story;
  }

  @override
  State<StatefulWidget> createState() {
    return _DashbookState();
  }
}

enum CurrentView {
  stories,
  properties,
  actions,
  deviceSettings,
}

class _DashbookState extends State<Dashbook> {
  Chapter? _currentChapter;
  CurrentView? _currentView;
  ThemeData? _currentTheme;
  late DashbookPreferences _preferences;
  bool _loading = true;
  String _storiesFilter = '';
  bool _storyPanelPinned = false;

  @override
  void initState() {
    super.initState();

    if (widget.theme != null) {
      _currentTheme = widget.theme;
    } else if (widget._dualTheme != null) {
      final dualTheme = widget._dualTheme;
      _currentTheme =
          dualTheme!.initWithLight ? dualTheme.light : dualTheme.dark;
    } else if (widget._multiTheme != null) {
      final multiTheme = widget._multiTheme;
      _currentTheme = multiTheme!.themes[multiTheme.initialTheme] ??
          multiTheme.themes.values.first;
    }
    _finishLoading();
  }

  Future<void> _finishLoading() async {
    final preferences = DashbookPreferences();
    await preferences.load();

    var initialChapter = PlatformUtils.getInitialChapter(widget.stories);

    if (initialChapter == null) {
      if (preferences.bookmarkedChapter != null) {
        initialChapter =
            findChapter(preferences.bookmarkedChapter!, widget.stories);
      } else if (widget.stories.isNotEmpty) {
        final story = widget.stories.first;

        if (story.chapters.isNotEmpty) {
          initialChapter = story.chapters.first;
        }
      }
    }

    if (initialChapter != null) {
      widget.onChapterChange?.call(initialChapter);
    }

    setState(() {
      _currentChapter = initialChapter;
      _preferences = preferences;
      _loading = false;
    });
  }

  bool _hasProperties() => _currentChapter?.ctx.properties.isNotEmpty ?? false;

  bool _hasActions() => _currentChapter?.ctx.actions.isNotEmpty ?? false;

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await url_launcher.canLaunchUrl(uri)) {
      await url_launcher.launchUrl(uri);
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container();
    }

    return DeviceSettings(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorKey: widget.navigatorKey,
        title: widget.title,
        theme: _currentTheme,
        localizationsDelegates: widget.localizationsDelegates,
        supportedLocales: widget.supportedLocales,
        onGenerateRoute: (settings) {
          return MaterialPageRoute<void>(
            builder: (context) {
              final chapterWidget = _currentChapter?.widget();
              final alwaysShowStories =
                  widget.autoPinStoriesOnLargeScreen && context.isWideScreen;

              return Scaffold(
                body: SafeArea(
                  child: Row(
                    children: [
                      if (_currentView == CurrentView.stories ||
                          alwaysShowStories)
                        Drawer(
                          child: StoriesList(
                            stories: widget.stories,
                            storyPanelPinned: _storyPanelPinned,
                            selectedChapter: _currentChapter,
                            currentBookmark: _preferences.bookmarkedChapter,
                            currentFilter: _storiesFilter,
                            onStoryPinChange: () {
                              setState(() {
                                _storyPanelPinned = !_storyPanelPinned;
                              });
                            },
                            storiesAreAlwaysShown: alwaysShowStories,
                            onUpdateFilter: (value) {
                              _storiesFilter = value;
                            },
                            onBookmarkChapter: (String bookmark) {
                              setState(() {
                                _preferences.bookmarkedChapter = bookmark;
                              });
                            },
                            onClearBookmark: () {
                              setState(() {
                                _preferences.bookmarkedChapter = null;
                              });
                            },
                            onCancel: () => setState(() {
                              _currentView = null;
                              _storyPanelPinned = false;
                            }),
                            onSelectChapter: (chapter) {
                              widget.onChapterChange?.call(chapter);
                              setState(() {
                                _currentChapter = chapter;
                                if (!_storyPanelPinned) {
                                  _currentView = null;
                                }
                              });
                            },
                          ),
                        ),
                      Expanded(
                        child: Stack(
                          children: [
                            if (_currentChapter != null &&
                                (context.isNotPhoneSize ||
                                    _currentView != CurrentView.stories))
                              PreviewContainer(
                                key: Key(_currentChapter!.id),
                                usePreviewSafeArea: widget.usePreviewSafeArea,
                                isIntrusiveSideMenuOpen: _currentView ==
                                        CurrentView.properties ||
                                    _currentView == CurrentView.actions ||
                                    _currentView == CurrentView.deviceSettings,
                                info: (_currentChapter?.pinInfo ?? false)
                                    ? _currentChapter?.info
                                    : null,
                                child: chapterWidget!,
                              ),
                            Positioned(
                              right: 10,
                              top: 0,
                              bottom: 0,
                              child: _DashbookRightIconList(
                                children: [
                                  if (_hasProperties())
                                    DashbookIcon(
                                      key: kPropertiesIcon,
                                      tooltip: 'Properties panel',
                                      icon: Icons.mode_edit,
                                      onClick: () => setState(
                                        () {
                                          _currentView = CurrentView.properties;
                                          _storyPanelPinned = false;
                                        },
                                      ),
                                    ),
                                  if (_hasActions())
                                    DashbookIcon(
                                      key: kActionsIcon,
                                      tooltip: 'Actions panel',
                                      icon: Icons.play_arrow,
                                      onClick: () => setState(
                                        () {
                                          _currentView = CurrentView.actions;
                                          _storyPanelPinned = false;
                                        },
                                      ),
                                    ),
                                  if (_currentChapter?.info != null &&
                                      _currentChapter?.pinInfo == false)
                                    DashbookIcon(
                                      tooltip: 'Instructions',
                                      icon: Icons.info,
                                      onClick: () {
                                        showPopup(
                                          context: context,
                                          builder: (_) {
                                            return InstructionsDialog(
                                              instructions:
                                                  _currentChapter!.info!,
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  if (_currentChapter?.codeLink != null)
                                    DashbookIcon(
                                      tooltip: 'See code',
                                      icon: Icons.code,
                                      onClick: () => _launchURL(
                                        _currentChapter!.codeLink!,
                                      ),
                                    ),
                                  if (widget._dualTheme != null)
                                    _DashbookDualThemeIcon(
                                      dualTheme: widget._dualTheme!,
                                      currentTheme: _currentTheme!,
                                      onChangeTheme: (theme) =>
                                          setState(() => _currentTheme = theme),
                                    ),
                                  if (widget._multiTheme != null)
                                    DashbookIcon(
                                      tooltip: 'Choose theme',
                                      icon: Icons.palette,
                                      onClick: () {
                                        showPopup(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title: const Text('Theme chooser'),
                                            content: DropdownButton<ThemeData>(
                                              value: _currentTheme,
                                              items: widget
                                                  ._multiTheme!.themes.entries
                                                  .map(
                                                    (entry) => DropdownMenuItem(
                                                      value: entry.value,
                                                      child: Text(entry.key),
                                                    ),
                                                  )
                                                  .toList(),
                                              onChanged: (value) {
                                                if (value != null) {
                                                  setState(
                                                    () => _currentTheme = value,
                                                  );
                                                }
                                                Navigator.of(context).pop();
                                              },
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  if (kIsWeb && _currentChapter != null)
                                    DashbookIcon(
                                      tooltip: 'Share this example',
                                      icon: Icons.share,
                                      onClick: () {
                                        final url = PlatformUtils.getChapterUrl(
                                          _currentChapter!,
                                        );
                                        Clipboard.setData(
                                          ClipboardData(text: url),
                                        );
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Link copied to your clipboard',
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  DashbookIcon(
                                    key: kDevicePreviewIcon,
                                    tooltip: 'Device preview',
                                    icon: Icons.phone_android_outlined,
                                    onClick: () => setState(() {
                                      _currentView = CurrentView.deviceSettings;
                                      _storyPanelPinned = false;
                                    }),
                                  ),
                                ],
                              ),
                            ),
                            if (_currentView != CurrentView.stories &&
                                !alwaysShowStories)
                              Positioned(
                                top: 5,
                                left: 10,
                                child: DashbookIcon(
                                  key: kStoriesIcon,
                                  tooltip: 'Navigator',
                                  icon: Icons.menu,
                                  onClick: () => setState(
                                    () => _currentView = CurrentView.stories,
                                  ),
                                ),
                              ),
                            if (_currentView == CurrentView.properties &&
                                _currentChapter != null)
                              Positioned(
                                top: 0,
                                right: 0,
                                bottom: 0,
                                child: PropertiesContainer(
                                  currentChapter: _currentChapter!,
                                  onCancel: () =>
                                      setState(() => _currentView = null),
                                  onPropertyChange: () {
                                    setState(() {});
                                  },
                                ),
                              ),
                            if (_currentView == CurrentView.actions &&
                                _currentChapter != null)
                              Positioned(
                                top: 0,
                                right: 0,
                                bottom: 0,
                                child: ActionsContainer(
                                  currentChapter: _currentChapter!,
                                  onCancel: () =>
                                      setState(() => _currentView = null),
                                ),
                              ),
                            if (_currentView == CurrentView.deviceSettings &&
                                _currentChapter != null)
                              Positioned(
                                top: 0,
                                right: 0,
                                bottom: 0,
                                child: DeviceSettingsContainer(
                                  onCancel: () => setState(
                                    () => _currentView = null,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _DashbookRightIconList extends StatelessWidget {
  final List<Widget> children;

  const _DashbookRightIconList({
    required this.children,
  });

  double _rightIconTop(int index, BuildContext ctx) =>
      10.0 + index * iconSize(ctx);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: iconSize(context),
      child: Stack(
        children: [
          for (int index = 0; index < children.length; index++)
            Positioned(
              top: _rightIconTop(index, context),
              child: children[index],
            ),
        ],
      ),
    );
  }
}

class _DashbookDualThemeIcon extends StatelessWidget {
  final _DashbookDualTheme dualTheme;
  final ThemeData currentTheme;
  final void Function(ThemeData) onChangeTheme;

  const _DashbookDualThemeIcon({
    required this.dualTheme,
    required this.currentTheme,
    required this.onChangeTheme,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkthemeSelected = dualTheme.dark == currentTheme;
    return DashbookIcon(
      tooltip: isDarkthemeSelected
          ? 'Change to light theme'
          : 'Change to dark theme',
      icon: isDarkthemeSelected ? Icons.nightlight_round : Icons.wb_sunny,
      onClick: () {
        if (isDarkthemeSelected) {
          onChangeTheme(dualTheme.light);
        } else {
          onChangeTheme(dualTheme.dark);
        }
      },
    );
  }
}
