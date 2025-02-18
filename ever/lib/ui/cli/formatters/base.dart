/// Base formatter interface for CLI output
abstract class OutputFormatter<T> {
  /// Format the input data into a string for CLI output
  String format(T data);
} 