/// The six separate kinds of log Moment records. Types are never merged:
/// each has its own table, create screen, section and detail page.
enum LogType { text, emoji, photo, video, audio, location }

/// The types offered in the app, in the order they appear in the Add
/// sheet, Library and filter chips. All six are built; a future type would
/// join here only once it is in backup, export, storage and Trash.
const builtLogTypes = LogType.values;
