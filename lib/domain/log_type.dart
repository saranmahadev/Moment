/// The six separate kinds of log Moment records. Types are never merged:
/// each has its own table, create screen, section and detail page.
enum LogType { text, emoji, photo, video, audio, location }

/// The types with a working create/read/update/delete path so far. Grows
/// by one line per phase; screens such as the Add sheet and the filter
/// chips use it to show only what is actually built.
const builtLogTypes = [
  LogType.text,
  LogType.emoji,
  LogType.photo,
  LogType.audio,
];
