import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../errors/failures.dart';
import '../result/result.dart';

abstract class FileService {
  /// Reads a file's entire content as a string.
  Future<Result<String, PlatformFailure>> readFileAsString(String filePath);

  /// Writes a string to a file, creating it if it doesn't exist.
  Future<Result<void, PlatformFailure>> writeFileAsString(
    String filePath,
    String content,
  );

  /// Reads a file's entire content as raw bytes.
  Future<Result<List<int>, PlatformFailure>> readFileAsBytes(String filePath);

  /// Writes bytes to a file, creating it if it doesn't exist.
  Future<Result<void, PlatformFailure>> writeFileAsBytes(
    String filePath,
    List<int> bytes,
  );

  /// Deletes a file if it exists.
  Future<Result<void, PlatformFailure>> deleteFile(String filePath);

  /// Resolves the application documents directory path.
  Future<Result<String, PlatformFailure>> getDocumentsDirectoryPath();
}

class FileServiceImpl implements FileService {
  const FileServiceImpl();

  @override
  Future<Result<String, PlatformFailure>> readFileAsString(
    String filePath,
  ) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return FailureResult(PlatformFailure('File not found at: $filePath'));
      }
      final content = await file.readAsString();
      return Success(content);
    } catch (e) {
      return FailureResult(
        PlatformFailure('Failed to read file as string: $filePath', e),
      );
    }
  }

  @override
  Future<Result<void, PlatformFailure>> writeFileAsString(
    String filePath,
    String content,
  ) async {
    try {
      final file = File(filePath);
      // Ensure parent directory exists
      final parent = file.parent;
      if (!await parent.exists()) {
        await parent.create(recursive: true);
      }
      await file.writeAsString(content);
      return const Success(null);
    } catch (e) {
      return FailureResult(
        PlatformFailure('Failed to write string to file: $filePath', e),
      );
    }
  }

  @override
  Future<Result<List<int>, PlatformFailure>> readFileAsBytes(
    String filePath,
  ) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return FailureResult(PlatformFailure('File not found at: $filePath'));
      }
      final bytes = await file.readAsBytes();
      return Success(bytes);
    } catch (e) {
      return FailureResult(
        PlatformFailure('Failed to read file as bytes: $filePath', e),
      );
    }
  }

  @override
  Future<Result<void, PlatformFailure>> writeFileAsBytes(
    String filePath,
    List<int> bytes,
  ) async {
    try {
      final file = File(filePath);
      // Ensure parent directory exists
      final parent = file.parent;
      if (!await parent.exists()) {
        await parent.create(recursive: true);
      }
      await file.writeAsBytes(bytes);
      return const Success(null);
    } catch (e) {
      return FailureResult(
        PlatformFailure('Failed to write bytes to file: $filePath', e),
      );
    }
  }

  @override
  Future<Result<void, PlatformFailure>> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
      return const Success(null);
    } catch (e) {
      return FailureResult(
        PlatformFailure('Failed to delete file: $filePath', e),
      );
    }
  }

  @override
  Future<Result<String, PlatformFailure>> getDocumentsDirectoryPath() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      return Success(directory.path);
    } catch (e) {
      return FailureResult(
        PlatformFailure('Failed to get application documents directory', e),
      );
    }
  }
}
