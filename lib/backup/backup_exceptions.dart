/// Anything that can go wrong reading a `.moment` backup. Each subclass maps
/// to one message the Privacy screen can show.
sealed class BackupException implements Exception {
  const BackupException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// The file is not a Moment backup, or is a version this app cannot read.
final class BackupFormatException extends BackupException {
  const BackupFormatException(super.message);
}

/// The passphrase does not open this backup.
final class WrongPassphraseException extends BackupException {
  const WrongPassphraseException()
    : super('The passphrase does not match this backup.');
}

/// The backup opened but its contents are damaged or incomplete.
final class CorruptBackupException extends BackupException {
  const CorruptBackupException(super.message);
}
