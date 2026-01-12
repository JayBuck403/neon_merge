import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IAPService {
  static final IAPService _instance = IAPService._internal();
  factory IAPService() => _instance;
  IAPService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  
  bool _available = false;
  bool _adsRemoved = false;
  List<ProductDetails> _products = [];

  // Product IDs - Replace with your actual product IDs
  static const String removeAdsId = 'remove_ads';
  static const String starterPackId = 'starter_pack';
  static const String megaPackId = 'mega_pack';
  static const String coinsSmallId = 'coins_small';
  static const String coinsMediumId = 'coins_medium';
  static const String coinsLargeId = 'coins_large';

  static const Set<String> _productIds = {
    removeAdsId,
    starterPackId,
    megaPackId,
    coinsSmallId,
    coinsMediumId,
    coinsLargeId,
  };

  Future<void> initialize() async {
    _available = await _iap.isAvailable();
    
    if (!_available) return;

    // Load previously purchased items
    await _loadPurchases();

    // Listen to purchase updates
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription?.cancel(),
      onError: (error) => debugPrint('Purchase error: $error'),
    );

    // Load products
    await _loadProducts();
  }

  Future<void> _loadPurchases() async {
    final prefs = await SharedPreferences.getInstance();
    _adsRemoved = prefs.getBool('ads_removed') ?? false;
  }

  Future<void> _loadProducts() async {
    if (!_available) return;

    final ProductDetailsResponse response = 
        await _iap.queryProductDetails(_productIds);

    if (response.error != null) {
      debugPrint('Error loading products: ${response.error}');
      return;
    }

    _products = response.productDetails;
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.purchased) {
        _handlePurchase(purchaseDetails);
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        debugPrint('Purchase error: ${purchaseDetails.error}');
      }

      if (purchaseDetails.pendingCompletePurchase) {
        _iap.completePurchase(purchaseDetails);
      }
    }
  }

  Future<void> _handlePurchase(PurchaseDetails purchaseDetails) async {
    final prefs = await SharedPreferences.getInstance();

    switch (purchaseDetails.productID) {
      case removeAdsId:
        _adsRemoved = true;
        await prefs.setBool('ads_removed', true);
        break;

      case starterPackId:
        // Give 3 random power-ups
        await _givePowerUps(3);
        break;

      case megaPackId:
        // Give 10 power-ups + remove ads
        await _givePowerUps(10);
        _adsRemoved = true;
        await prefs.setBool('ads_removed', true);
        break;

      case coinsSmallId:
        await _giveCoins(100);
        break;

      case coinsMediumId:
        await _giveCoins(500);
        break;

      case coinsLargeId:
        await _giveCoins(1500);
        break;
    }
  }

  Future<void> _givePowerUps(int count) async {
    // This will be handled by PowerUpInventory
    debugPrint('Giving $count power-ups');
  }

  Future<void> _giveCoins(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final currentCoins = prefs.getInt('coins') ?? 0;
    await prefs.setInt('coins', currentCoins + amount);
  }

  Future<bool> buyProduct(String productId) async {
    if (!_available) return false;

    final product = _products.firstWhere(
      (p) => p.id == productId,
      orElse: () => throw Exception('Product not found'),
    );

    final purchaseParam = PurchaseParam(productDetails: product);
    
    try {
      if (productId == removeAdsId || productId == megaPackId) {
        // Non-consumable
        return await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      } else {
        // Consumable
        return await _iap.buyConsumable(purchaseParam: purchaseParam);
      }
    } catch (e) {
      debugPrint('Purchase error: $e');
      return false;
    }
  }

  Future<void> restorePurchases() async {
    if (!_available) return;
    await _iap.restorePurchases();
  }

  bool get adsRemoved => _adsRemoved;
  bool get isAvailable => _available;
  List<ProductDetails> get products => _products;

  ProductDetails? getProduct(String productId) {
    try {
      return _products.firstWhere((p) => p.id == productId);
    } catch (e) {
      return null;
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}