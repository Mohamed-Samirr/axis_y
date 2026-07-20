/// A lightweight success/failure wrapper so repositories never throw raw
/// exceptions into Cubits.
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  /// Returns the value on success, or null on failure.
  T? get valueOrNull => this is Success<T> ? (this as Success<T>).data : null;

  R when<R>({
    required R Function(T data) success,
    required R Function(String message) failure,
  }) {
    final self = this;
    if (self is Success<T>) return success(self.data);
    return failure((self as Failure<T>).message);
  }
}

class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

class Failure<T> extends Result<T> {
  final String message;
  const Failure(this.message);
}
