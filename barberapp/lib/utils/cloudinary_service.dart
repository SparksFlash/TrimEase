import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http; // used for delete-by-token
import 'package:image_picker/image_picker.dart';
// http_parser used previously to build MediaType; no longer required.
// import 'package:http_parser/http_parser.dart';
import '../config/cloudinary_config.dart';

class CloudinaryService {
  /// Upload a picked file to Cloudinary and optionally report progress.
  ///
  /// `onProgress(sent, total)` will be called with bytes sent and total bytes.
  static Future<Map<String, dynamic>> uploadXFile(
    XFile file, {
    String? folder,
    void Function(int sent, int total)? onProgress,
  }) async {
    final cloud = CLOUDINARY_CLOUD_NAME;
    final preset = CLOUDINARY_UPLOAD_PRESET;
    if (cloud == 'YOUR_CLOUD_NAME' || preset == 'YOUR_UNSIGNED_UPLOAD_PRESET') {
      throw Exception(
        'Please configure Cloudinary settings in cloudinary_config.dart',
      );
    }

    final uri = 'https://api.cloudinary.com/v1_1/$cloud/image/upload';

    final bytes = await file.readAsBytes();
    final fileName = file.name;

    // We read the bytes and filename; do not force a per-part content-type.

    // Build form data. Avoid forcing a contentType on the MultipartFile
    // because Dio will set the correct multipart header (including boundary)
    // and the internal content-type for the part.
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
      'upload_preset': preset,
      // be explicit about resource type to avoid ambiguity
      'resource_type': 'image',
      if (folder != null && folder.isNotEmpty) 'folder': folder,
    });

    final dio = Dio();
    try {
      // Do not override the contentType header; Dio will add the
      // correct multipart/form-data header including the boundary.
      final resp = await dio.post(
        uri,
        data: formData,
        // Don't throw on 4xx/5xx so we can include the response body in our
        // error message and give a clearer reason for failures.
        options: Options(
          headers: {'Accept': 'application/json'},
          validateStatus: (_) => true,
        ),
        onSendProgress: onProgress,
      );

      // If server returned 2xx, parse and return JSON.
      if (resp.statusCode != null &&
          resp.statusCode! >= 200 &&
          resp.statusCode! < 300) {
        if (resp.data is Map<String, dynamic>)
          return resp.data as Map<String, dynamic>;
        if (resp.data is String)
          return json.decode(resp.data as String) as Map<String, dynamic>;
        return Map<String, dynamic>.from(resp.data);
      }

      // Non-2xx: include the server response body in the thrown exception
      final body = resp.data is String ? resp.data : json.encode(resp.data);
      throw Exception('Cloudinary upload failed: ${resp.statusCode} - $body');
    } on DioError catch (dioErr) {
      // If Cloudinary returns an error payload, include it in the exception
      final resp = dioErr.response;
      if (resp != null && resp.data != null) {
        try {
          final body =
              resp.data is String
                  ? json.decode(resp.data as String)
                  : resp.data;
          throw Exception(
            'Cloudinary upload error: ${resp.statusCode} ${resp.statusMessage} - $body',
          );
        } catch (_) {
          throw Exception(
            'Cloudinary upload error: ${resp.statusCode} ${resp.statusMessage} - ${resp.data}',
          );
        }
      }
      throw Exception('Cloudinary upload error: ${dioErr.message}');
    } catch (e) {
      // normalize other errors for callers
      throw Exception('Cloudinary upload error: $e');
    }
  }

  /// Delete by token returned during upload when `return_delete_token=true`.
  static Future<bool> deleteByToken(String token) async {
    final cloud = CLOUDINARY_CLOUD_NAME;
    if (cloud == 'YOUR_CLOUD_NAME') {
      throw Exception(
        'Please configure Cloudinary settings in cloudinary_config.dart',
      );
    }
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloud/delete_by_token',
    );
    final resp = await http.post(uri, body: {'token': token});
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final map = json.decode(resp.body) as Map<String, dynamic>;
      return map['result'] == 'ok';
    }
    return false;
  }
}
