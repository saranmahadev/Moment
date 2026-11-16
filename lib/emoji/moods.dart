/// The twelve moods Moment names, in the grid order of the New Emoji
/// screen. Labels for 😊, 😌, 😐, 😔 and 😤 come from the mockups; the rest
/// are reasonable choices, since the mockups do not name them.
const moodPalette = [
  ('😊', 'Happy'),
  ('😌', 'Calm'),
  ('🙂', 'Content'),
  ('😄', 'Joyful'),
  ('🥰', 'Loved'),
  ('😴', 'Tired'),
  ('😐', 'Neutral'),
  ('😔', 'Sad'),
  ('😢', 'Crying'),
  ('😤', 'Frustrated'),
  ('😰', 'Anxious'),
  ('🤒', 'Unwell'),
];

/// The five moods on Home's quick row until the owner chooses others.
const defaultQuickEmoji = ['😊', '😌', '😐', '😔', '😤'];

/// The name of [emoji] in [moodPalette], or null for one it does not hold.
String? moodLabel(String emoji) {
  for (final (candidate, label) in moodPalette) {
    if (candidate == emoji) return label;
  }
  return null;
}
