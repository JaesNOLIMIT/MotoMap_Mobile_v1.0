import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/motorcycle.dart';
import '../models/rider_profile.dart';
import 'motorcycle_service.dart';

class ImageStorageService {
  ImageStorageService._();

  static final instance = ImageStorageService._();
  static const profileBucket = 'profile-images';
  static const motorcycleBucket = 'motorcycle-images';
  static const maxBytes = 5 * 1024 * 1024;

  SupabaseClient get _client => Supabase.instance.client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('No authenticated rider.');
    return user.id;
  }

  Future<String> uploadProfileImage({
    required RiderProfile profile,
    required XFile file,
  }) async {
    final upload = await _prepare(file);
    final path =
        '$_userId/avatar-${DateTime.now().millisecondsSinceEpoch}'
        '.${upload.extension}';
    await _upload(profileBucket, path, upload);
    try {
      await _client
          .from('profiles')
          .update({'avatar_path': path})
          .eq('user_id', _userId);
    } catch (_) {
      await _client.storage.from(profileBucket).remove([path]);
      rethrow;
    }
    await _removePrevious(profileBucket, profile.avatarPath, except: path);
    return path;
  }

  Future<String> uploadMotorcycleImage({
    required Motorcycle motorcycle,
    required XFile file,
  }) async {
    final upload = await _prepare(file);
    final path =
        '$_userId/${motorcycle.id}/photo-'
        '${DateTime.now().millisecondsSinceEpoch}.${upload.extension}';
    await _upload(motorcycleBucket, path, upload);
    try {
      await _client
          .from('motorcycles')
          .update({'photo_path': path})
          .eq('motorcycle_id', motorcycle.id)
          .eq('user_id', _userId);
    } catch (_) {
      await _client.storage.from(motorcycleBucket).remove([path]);
      rethrow;
    }
    await _removePrevious(motorcycleBucket, motorcycle.photoPath, except: path);
    MotorcycleService.instance.changes.value++;
    return path;
  }

  String publicUrl(String bucket, String? path) {
    if (path == null || path.isEmpty) return '';
    return _client.storage.from(bucket).getPublicUrl(path);
  }

  Future<void> _upload(String bucket, String path, _PreparedImage image) async {
    await _client.storage
        .from(bucket)
        .uploadBinary(
          path,
          image.bytes,
          fileOptions: FileOptions(
            cacheControl: '3600',
            contentType: image.contentType,
            upsert: false,
          ),
        );
  }

  Future<_PreparedImage> _prepare(XFile file) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) throw StateError('The selected image is empty.');
    if (bytes.length > maxBytes) {
      throw StateError('The selected image is larger than 5 MB.');
    }

    final source = '${file.name}.${file.mimeType ?? ''}'.toLowerCase();
    if (source.contains('png')) {
      return _PreparedImage(bytes, 'png', 'image/png');
    }
    if (source.contains('webp')) {
      return _PreparedImage(bytes, 'webp', 'image/webp');
    }
    if (source.contains('jpg') || source.contains('jpeg')) {
      return _PreparedImage(bytes, 'jpg', 'image/jpeg');
    }
    throw StateError('Choose a JPEG, PNG, or WebP image.');
  }

  Future<void> _removePrevious(
    String bucket,
    String? previous, {
    required String except,
  }) async {
    if (previous == null || previous.isEmpty || previous == except) return;
    await _client.storage.from(bucket).remove([previous]);
  }
}

class _PreparedImage {
  const _PreparedImage(this.bytes, this.extension, this.contentType);

  final Uint8List bytes;
  final String extension;
  final String contentType;
}
