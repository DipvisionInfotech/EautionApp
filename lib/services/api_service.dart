import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Set to true to force connection to the local development server in debug mode
  static const bool useLocalHostInDebug = true;

  // Dynamically switch between local dev and production server
  static const String baseUrl = (kDebugMode && useLocalHostInDebug)
      ? (kIsWeb ? 'http://127.0.0.1:8000/api' : 'http://10.0.2.2:8000/api')
      : 'https://eauction-backend.dipvisioninfotech.com/api';

  static Future<void> saveTokens(String access, String refresh) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', access);
    await prefs.setString('refresh_token', refresh);
  }

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }

  static Future<Map<String, dynamic>> register(
      String email, String password, String fullName, String role,
      {List<String>? preferredCategories}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'full_name': fullName,
        'role': role.toLowerCase(), // 'buyer' is mapped to 'bidder' in Django
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

  // Auction Rooms Methods
  static Future<Map<String, dynamic>> getRooms() async {
    final token = await getAccessToken();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/rooms/'),
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
      headers: {'Content-Type': 'application/json'},
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
}

