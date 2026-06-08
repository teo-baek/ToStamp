import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/network/api_client.dart';

/// 고객 거래소 — 머니 충전 + 매물 둘러보기/구매 + 내 도장 팔기
class ExchangeScreen extends StatefulWidget {
  final String guestId;

  const ExchangeScreen({super.key, required this.guestId});

  @override
  State<ExchangeScreen> createState() => _ExchangeScreenState();
}

class _ExchangeScreenState extends State<ExchangeScreen> {
  final ApiClient _api = ApiClient();

  int _balance = 0;
  List<Map<String, dynamic>> _listings = [];
  List<Map<String, dynamic>> _myCards = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _api.getMoneyBalance(widget.guestId),
        _api.getListings(),
        _api.getStampCards(widget.guestId),
      ]);
      if (!mounted) return;
      setState(() {
        _balance = results[0] as int;
        _listings = (results[1] as List).cast<Map<String, dynamic>>();
        _myCards = (results[2] as List).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String m, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: c,
          behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _topup() async {
    final amount = await _amountDialog('머니 충전', '충전할 금액 (원)');
    if (amount == null) return;
    try {
      final bal = await _api.topupMoney(widget.guestId, amount);
      setState(() => _balance = bal);
      _snack('₩$amount 충전 완료', AppColors.success);
    } catch (e) {
      _snack('충전 실패: $e', AppColors.error);
    }
  }

  Future<void> _buy(Map<String, dynamic> listing) async {
    final ask = listing['ask_price_krw'] ?? 0;
    if (_balance < ask) {
      _snack('머니가 부족해요 (₩$ask 필요)', AppColors.error);
      return;
    }
    try {
      await _api.buyListing(
          guestId: widget.guestId, listingId: listing['id']);
      _snack('구매 완료! 도장이 카드에 담겼어요', AppColors.stampGold);
      await _load();
    } catch (e) {
      _snack('구매 실패: $e', AppColors.error);
    }
  }

  Future<void> _sell() async {
    final sellable = _myCards
        .where((c) => (c['current_stamps'] ?? 0) > 0 && c['is_completed'] != true)
        .toList();
    if (sellable.isEmpty) {
      _snack('팔 수 있는 도장이 없어요', AppColors.warmGray);
      return;
    }
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.warmWhite,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _SellSheet(
        cards: sellable,
        onSell: (card, qty, price) async {
          try {
            await _api.createListing(
              guestId: widget.guestId,
              storeId: card['store_id'],
              qty: qty,
              askPriceKrw: price,
            );
            if (mounted) Navigator.pop(context);
            _snack('매물 등록 완료', AppColors.success);
            await _load();
          } catch (e) {
            _snack('등록 실패: $e', AppColors.error);
          }
        },
      ),
    );
  }

  Future<int?> _amountDialog(String title, String hint) async {
    final ctrl = TextEditingController();
    return showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.warmWhite,
        title: Text(title, style: AppTypography.h3),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: hint, suffixText: '원'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, int.tryParse(ctrl.text.trim())),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softBeige,
      appBar: AppBar(
        title: Text('도장 거래소',
            style: AppTypography.h3.copyWith(color: AppColors.darkBrown)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _sell,
        backgroundColor: AppColors.stampGold,
        icon: const Icon(Icons.sell_outlined, color: Colors.white),
        label: Text('내 도장 팔기',
            style: AppTypography.labelLarge.copyWith(color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.stampGold))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.stampGold,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // 머니 잔액 카드
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [
                        AppColors.darkBrown,
                        AppColors.warmBrown,
                      ]),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('내 ToStamp 머니',
                                  style: AppTypography.bodySmall
                                      .copyWith(color: Colors.white70)),
                              const SizedBox(height: 4),
                              Text('₩$_balance',
                                  style: AppTypography.h1
                                      .copyWith(color: Colors.white)),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _topup,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.stampGold,
                          ),
                          child: const Text('충전'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('거래소 매물',
                      style: AppTypography.h3
                          .copyWith(color: AppColors.darkBrown)),
                  const SizedBox(height: 12),
                  if (_listings.isEmpty)
                    _empty('아직 올라온 매물이 없어요')
                  else
                    ..._listings.map(_listingCard),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  Widget _empty(String msg) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.warmWhite,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(msg,
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.warmGray)),
        ),
      );

  Widget _listingCard(Map<String, dynamic> l) {
    final qty = l['stamp_qty'] ?? 0;
    final ask = l['ask_price_krw'] ?? 0;
    final face = (l['unit_face_value_krw'] ?? 0) * qty;
    final discount = face > 0 ? (100 - (ask * 100 / face)).round() : 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warmWhite,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.approval, color: AppColors.stampGold),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('도장 $qty개',
                    style: AppTypography.bodyLarge.copyWith(
                        color: AppColors.darkBrown,
                        fontWeight: FontWeight.w600)),
                Text('액면 ₩$face' + (discount > 0 ? ' · $discount% 할인' : ''),
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.warmGray)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₩$ask',
                  style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.stampGold,
                      fontWeight: FontWeight.w700)),
              SizedBox(
                height: 32,
                child: ElevatedButton(
                  onPressed: () => _buy(l),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text('구매'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 도장 팔기 바텀시트
class _SellSheet extends StatefulWidget {
  final List<Map<String, dynamic>> cards;
  final Future<void> Function(Map<String, dynamic> card, int qty, int price)
      onSell;

  const _SellSheet({required this.cards, required this.onSell});

  @override
  State<_SellSheet> createState() => _SellSheetState();
}

class _SellSheetState extends State<_SellSheet> {
  late Map<String, dynamic> _card;
  int _qty = 1;
  final _priceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _card = widget.cards.first;
  }

  int get _maxQty => _card['current_stamps'] ?? 1;
  int get _faceTotal => (_card['face_value_krw'] ?? 0) * _qty;

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('내 도장 팔기',
              style: AppTypography.h3.copyWith(color: AppColors.darkBrown)),
          const SizedBox(height: 16),
          DropdownButton<Map<String, dynamic>>(
            value: _card,
            isExpanded: true,
            items: widget.cards
                .map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(
                          '${c['store_name']} · 보유 ${c['current_stamps']}개'),
                    ))
                .toList(),
            onChanged: (c) => setState(() {
              _card = c!;
              if (_qty > _maxQty) _qty = _maxQty;
            }),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('수량', style: AppTypography.labelLarge),
              const Spacer(),
              IconButton(
                onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$_qty개', style: AppTypography.h3),
              IconButton(
                onPressed:
                    _qty < _maxQty ? () => setState(() => _qty++) : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _priceController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: '판매 가격 (액면가 ₩$_faceTotal 이하)',
              suffixText: '원',
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                final price = int.tryParse(_priceController.text.trim()) ?? 0;
                if (price <= 0 || price > _faceTotal) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('가격은 1~$_faceTotal원 사이여야 해요'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                  return;
                }
                widget.onSell(_card, _qty, price);
              },
              child: const Text('매물 등록'),
            ),
          ),
        ],
      ),
    );
  }
}
