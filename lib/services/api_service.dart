import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Set to false so debug mode also uses the live production backend
  static const bool useLocalHostInDebug = false;

  // Dynamically switch between local dev and production server
  static const String baseUrl = (kDebugMode && useLocalHostInDebug)
      ? (kIsWeb ? 'http://127.0.0.1:8000/api' : 'http://10.0.2.2:8000/api')
      : 'https://eauction-backend.dipvisioninfotech.com/api';

  static MediaType _getMediaType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) {
      return MediaType('application', 'pdf');
    } else if (lower.endsWith('.png')) {
      return MediaType('image', 'png');
    } else if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return MediaType('image', 'jpeg');
    } else if (lower.endsWith('.webp')) {
      return MediaType('image', 'webp');
    }
    return MediaType('application', 'octet-stream');
  }

  static Future<void> saveTokens(String access, String refresh) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', access);
    await prefs.setString('refresh_token', refresh);
  }

  static bool isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final map = jsonDecode(payload);
      final exp = map['exp'] as int?;
      if (exp == null) return false;
      final expiryDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      // Use a 10 seconds buffer
      return DateTime.now().add(const Duration(seconds: 10)).isAfter(expiryDate);
    } catch (_) {
      return true;
    }
  }

  static Future<String?> refreshAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final refresh = prefs.getString('refresh_token');
    if (refresh == null) return null;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/token/refresh/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': refresh}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newAccess = data['access'] as String?;
        if (newAccess != null) {
          await prefs.setString('access_token', newAccess);
          final newRefresh = data['refresh'] as String?;
          if (newRefresh != null) {
            await prefs.setString('refresh_token', newRefresh);
          }
          return newAccess;
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final access = prefs.getString('access_token');
    if (access == null) return null;

    if (isTokenExpired(access)) {
      final refreshed = await refreshAccessToken();
      if (refreshed != null) {
        return refreshed;
      }
      await clearTokens();
      return null;
    }
    return access;
  }

  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }

  static Future<Map<String, dynamic>> register(
      String email, String password, String fullName, String role,
      {String? phone, String? address, List<String>? preferredCategories}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'full_name': fullName,
        'role': role.toLowerCase(), // 'buyer' is mapped to 'bidder' in Django
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (address != null && address.isNotEmpty) 'address': address,
        if (preferredCategories != null) 'preferred_categories': preferredCategories,
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      await saveTokens(data['tokens']['access'], data['tokens']['refresh']);
      return {'success': true, 'data': data};
    } else {
      return {'success': false, 'error': jsonDecode(response.body)};
    }
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await saveTokens(data['tokens']['access'], data['tokens']['refresh']);
      return {'success': true, 'data': data};
    } else {
      return {'success': false, 'error': jsonDecode(response.body)};
    }
  }

  static Future<Map<String, dynamic>> getProfile() async {
    final token = await getAccessToken();
    if (token == null) return {'success': false, 'error': 'No token'};

    final response = await http.get(
      Uri.parse('$baseUrl/auth/profile/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return {'success': true, 'data': jsonDecode(response.body)};
    } else {
      return {'success': false, 'error': jsonDecode(response.body)};
    }
  }

  static Future<Map<String, dynamic>> uploadKYCDocument(
      String type, List<int> fileBytes, String fileName) async {
    final token = await getAccessToken();
    if (token == null) return {'success': false, 'error': 'No token'};

    try {
      final mediaType = _getMediaType(fileName);
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/kyc/submit/'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['type'] = type;
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName,
        contentType: mediaType,
      ));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 400) {
        try {
          final body = jsonDecode(response.body);
          if (body is Map && body['error'] != null && body['error'].toString().contains('already exists')) {
            request = http.MultipartRequest(
              'PUT',
              Uri.parse('$baseUrl/kyc/replace/$type/'),
            );
            request.headers['Authorization'] = 'Bearer $token';
            request.fields['type'] = type;
            request.files.add(http.MultipartFile.fromBytes(
              'file',
              fileBytes,
              filename: fileName,
              contentType: mediaType,
            ));
            streamedResponse = await request.send();
            response = await http.Response.fromStream(streamedResponse);
          }
        } catch (_) {}
      }

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'error': jsonDecode(response.body)};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getKYCStatus() async {
    final token = await getAccessToken();
    if (token == null) return {'success': false, 'error': 'No token'};

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/kyc/status/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'error': jsonDecode(response.body)};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> deleteKYCDocument(String type) async {
    final token = await getAccessToken();
    if (token == null) return {'success': false, 'error': 'No token'};

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/kyc/replace/$type/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'error': jsonDecode(response.body)};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> downloadKYCDocument(String type) async {
    final token = await getAccessToken();
    if (token == null) return {'success': false, 'error': 'No token'};

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/kyc/documents/$type/'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        String? filename;
        final disposition = response.headers['content-disposition'];
        if (disposition != null && disposition.contains('filename=')) {
          final match = RegExp(r'filename="?([^";\n]+)"?').firstMatch(disposition);
          if (match != null && match.group(1) != null) {
            filename = match.group(1);
          }
        }
        filename ??= '${type}_document.pdf';
        return {
          'success': true,
          'bytes': response.bodyBytes,
          'filename': filename,
          'contentType': response.headers['content-type'] ?? 'application/pdf',
        };
      } else {
        return {'success': false, 'error': 'Download failed with status ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }


  // Auction Rooms Methods
  static Future<Map<String, dynamic>> getRooms({bool past = false}) async {
    final token = await getAccessToken();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';

    try {
      final url = past ? '$baseUrl/rooms/?past=true' : '$baseUrl/rooms/';
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'error': jsonDecode(response.body)};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> getRoomDetails(String roomId) async {
    final token = await getAccessToken();
    final headers = {'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await http.get(
      Uri.parse('$baseUrl/rooms/$roomId/'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return {'success': true, 'data': jsonDecode(response.body)};
    } else {
      return {'success': false, 'error': jsonDecode(response.body)};
    }
  }

  static Future<Map<String, dynamic>> getGroupCategories(String roomId) async {
    final token = await getAccessToken();
    final headers = {'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/rooms/$roomId/group-categories/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      } else {
        return {'success': false, 'error': jsonDecode(response.body)};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> joinRoom(String roomId) async {
    final token = await getAccessToken();
    if (token == null) return {'success': false, 'error': 'Not logged in'};

    final response = await http.post(
      Uri.parse('$baseUrl/rooms/$roomId/join/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return {'success': true, 'data': jsonDecode(response.body)};
    } else {
      return {'success': false, 'error': jsonDecode(response.body)};
    }
  }

  static Future<Map<String, dynamic>> registerInterest(
    String roomId, {
    String? message,
    String? contactPreference,
    String? ddNumber,
    String? ddBank,
    String? ddDate,
    double? ddAmount,
    String? ddFile,
  }) async {
    final token = await getAccessToken();
    if (token == null) return {'success': false, 'error': 'Not logged in'};

    final bodyData = <String, dynamic>{
      if (message != null) 'message': message,
      'contact_preference': contactPreference ?? 'email',
      if (ddNumber != null && ddNumber.isNotEmpty) 'dd_number': ddNumber,
      if (ddBank != null && ddBank.isNotEmpty) 'dd_bank': ddBank,
      if (ddDate != null && ddDate.isNotEmpty) 'dd_date': ddDate,
      if (ddAmount != null) 'dd_amount': ddAmount,
      if (ddFile != null && ddFile.isNotEmpty) 'dd_file': ddFile,
    };

    final response = await http.post(
      Uri.parse('$baseUrl/rooms/$roomId/register-interest/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(bodyData),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return {'success': true};
    } else {
      try {
        return {'success': false, 'error': jsonDecode(response.body)};
      } catch (_) {
        return {'success': false, 'error': 'Failed to register interest'};
      }
    }
  }

  static Future<Map<String, dynamic>> uploadDDDocument(
      String roomId, List<int> fileBytes, String fileName) async {
    final token = await getAccessToken();
    if (token == null) return {'success': false, 'error': 'No token'};

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/rooms/$roomId/upload-dd/'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName,
      ));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'object_key': data['object_key'], 'url': data['url']};
      } else {
        return {'success': false, 'error': jsonDecode(response.body)};
      }
    } catch (e) {
      return {'success': false, 'error': 'Failed to upload document'};
    }
  }

  // Categories
  static Future<List<dynamic>> getCategories() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/categories/'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> raw = jsonDecode(response.body) as List<dynamic>;
        final List<dynamic> flatList = [];
        for (var parent in raw) {
          // Add top-level category
          flatList.add({
            'id': parent['id'],
            'name': parent['name'],
            'slug': parent['slug'],
            'parent_id': null,
          });
          
          // Add sub-categories indented for visual representation in dropdowns
          if (parent['subcategories'] != null) {
            for (var sub in parent['subcategories']) {
              flatList.add({
                'id': sub['id'],
                'name': '  └─ ${sub['name']}',
                'slug': sub['slug'],
                'parent_id': parent['id'],
              });
            }
          }
        }
        return flatList;
      }
    } catch (_) {}
    return [];
  }

  // Classifieds
  static Future<Map<String, dynamic>> getClassifieds({
    int page = 1,
    String? categorySlug,
    String? location,
    String? search,
  }) async {
    final params = <String, String>{'page': page.toString()};
    if (categorySlug != null && categorySlug.isNotEmpty) params['category'] = categorySlug;
    if (location != null && location.isNotEmpty) params['location'] = location;
    if (search != null && search.isNotEmpty) params['search'] = search;

    final uri = Uri.parse('$baseUrl/classifieds/').replace(queryParameters: params);
    final response = await http.get(uri, headers: {'Content-Type': 'application/json'});

    if (response.statusCode == 200) {
      return {'success': true, 'data': jsonDecode(response.body)};
    } else {
      return {'success': false, 'error': jsonDecode(response.body)};
    }
  }

  static Future<Map<String, dynamic>> getClassifiedDetail(String id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/classifieds/$id/'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      return {'success': true, 'data': jsonDecode(response.body)};
    } else {
      return {'success': false, 'error': jsonDecode(response.body)};
    }
  }

  static Future<Map<String, dynamic>> submitEnquiry({
    required String name,
    required String email,
    required String phone,
    required String message,
    String? auctionId,  // Optional auction ID
  }) async {
    final token = await getAccessToken();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final body = {
      'name': name,
      'email': email,
      'phone': phone,
      'message': message,
    };
    
    // Add auction_id if provided
    if (auctionId != null && auctionId.isNotEmpty) {
      body['auction_id'] = auctionId;
      print('DEBUG: Adding auction_id to request: $auctionId');
    } else {
      print('DEBUG: No auction_id provided');
    }
    
    print('DEBUG: Request body: ${jsonEncode(body)}');
    
    final response = await http.post(
      Uri.parse('$baseUrl/enquiry/'),
      headers: headers,
      body: jsonEncode(body),
    );

    print('DEBUG: Response status: ${response.statusCode}');
    print('DEBUG: Response body: ${response.body}');

    if (response.statusCode == 201) {
      return {'success': true};
    } else {
      return {'success': false, 'error': jsonDecode(response.body)};
    }
  }

  // Cities
  static Future<List<dynamic>> getCities() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/cities/'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      }
    } catch (_) {}
    return [];
  }

  // Contact Us Message Submission
  static Future<Map<String, dynamic>> submitContactUsMessage({
    required String name,
    required String email,
    required String subject,
    required String message,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/contact/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'subject': subject,
          'message': message,
        }),
      );

      if (response.statusCode == 201) {
        return {'success': true};
      } else {
        return {'success': false, 'error': jsonDecode(response.body)};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error'};
    }
  }

  // Live Auction WebSocket Auth
  static Future<Map<String, dynamic>> getWebSocketToken(String roomId) async {
    final token = await getAccessToken();
    if (token == null) return {'success': false, 'error': 'Not logged in'};

    final response = await http.get(
      Uri.parse('$baseUrl/bidding/rooms/$roomId/ws-token/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {'success': true, 'token': data['token']};
    } else {
      return {'success': false, 'error': jsonDecode(response.body)};
    }
  }

  // Ephemeral Bidding Session Login
  static Future<Map<String, dynamic>> ephemeralLogin(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/ephemeral-login/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'token': data['token'],
          'roomId': data['room_id'],
          'userId': data['user_id']
        };
      } else {
        return {'success': false, 'error': jsonDecode(response.body)};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error'};
    }
  }

  // Seller Enquiries
  static Future<Map<String, dynamic>> submitSellerEnquiry({required String message}) async {
    final token = await getAccessToken();
    if (token == null) return {'success': false, 'error': 'Not logged in'};

    final response = await http.post(
      Uri.parse('$baseUrl/enquiry/my/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'message': message,
      }),
    );

    if (response.statusCode == 201) {
      return {'success': true, 'data': jsonDecode(response.body)};
    } else {
      return {'success': false, 'error': jsonDecode(response.body)};
    }
  }

  static Future<Map<String, dynamic>> getSellerEnquiries() async {
    final token = await getAccessToken();
    if (token == null) return {'success': false, 'error': 'Not logged in'};

    final response = await http.get(
      Uri.parse('$baseUrl/enquiry/my/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return {'success': true, 'data': jsonDecode(response.body)};
    } else {
      return {'success': false, 'error': jsonDecode(response.body)};
    }
  }
}


