import 'dart:typed_data';

import '../../core/api_client.dart';
import '../../core/mobile_api_endpoints.dart';
import 'card_models.dart';

class CardService {
  const CardService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<BankCardModel>> getMyCards(String token) async {
    final json = await _apiClient.getJsonList(
      MobileApiEndpoints.cards,
      token: token,
    );

    return json.map(BankCardModel.fromJson).toList();
  }

  Future<CardRequestModel> createRequest({
    required String token,
    required String cardholderName,
    required String currency,
    required String documentNumber,
    required String deliveryAddress,
    String? note,
  }) async {
    final json = await _apiClient.postJson(
      MobileApiEndpoints.cardRequests,
      {
        'cardholderName': cardholderName,
        'currency': currency,
        'documentNumber': documentNumber,
        'deliveryAddress': deliveryAddress,
        'note': note,
      },
      token: token,
    );

    return CardRequestModel.fromJson(json);
  }

  Future<List<CardRequestModel>> getMyRequests(String token) async {
    final json = await _apiClient.getJson(
      '${MobileApiEndpoints.myCardRequests}?page=1&pageSize=20',
      token: token,
    );

    final items = json['items'];
    if (items is! List) {
      return [];
    }

    return items
        .map((item) => CardRequestModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<CardRequestModel> uploadDocument({
    required String token,
    required String requestId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final json = await _apiClient.postMultipartBytes(
      MobileApiEndpoints.cardRequestDocuments(requestId),
      fieldName: 'file',
      fileName: fileName,
      bytes: bytes,
      token: token,
    );

    return CardRequestModel.fromJson(json);
  }
}
